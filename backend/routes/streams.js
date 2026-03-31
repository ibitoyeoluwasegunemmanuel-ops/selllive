// routes/streams.js — Live stream management
const express = require('express');
const router = express.Router();
const axios = require('axios');
const Joi = require('joi');
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// ============================================================
// Create a Daily.co room for the stream
// ============================================================
const createDailyRoom = async (streamId) => {
  const response = await axios.post(
    'https://api.daily.co/v1/rooms',
    {
      name: `selllive-${streamId}`,
      properties: {
        max_participants: 5000,  // viewers + seller
        enable_chat: false,      // we handle chat ourselves
        enable_knocking: false,
        exp: Math.floor(Date.now() / 1000) + (8 * 60 * 60), // 8 hour expiry
      },
    },
    {
      headers: { Authorization: `Bearer ${process.env.DAILY_API_KEY}` },
    }
  );
  return response.data;
};

// ============================================================
// GET /api/streams
// Get all live streams (the home feed)
// ============================================================
router.get('/', async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  const { data: streams, error } = await supabase
    .from('streams')
    .select(`
      id, title, thumbnail_url, status, viewer_count, total_orders, started_at,
      seller:users!seller_id(id, name, avatar_url),
      seller_profile:seller_profiles!inner(business_name, trust_score, followers_count),
      products:stream_products(id, name, price, image_url, is_active)
    `)
    .eq('status', 'live')
    .order('viewer_count', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) return res.status(500).json({ error: 'Failed to fetch streams.' });

  res.json({ streams, page: Number(page), limit: Number(limit) });
});

// ============================================================
// POST /api/streams
// Seller creates a new stream (go live)
// ============================================================
router.post('/', authenticate, sellerOnly, async (req, res) => {
  const schema = Joi.object({
    title: Joi.string().min(3).max(200).required(),
    description: Joi.string().max(500),
    thumbnail_url: Joi.string().uri(),
  });

  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  // Create stream record
  const { data: stream, error: dbError } = await supabase
    .from('streams')
    .insert({
      seller_id: req.user.id,
      ...value,
      status: 'live',
      started_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (dbError) return res.status(500).json({ error: 'Failed to create stream.' });

  // Create Daily.co room
  let dailyRoom = null;
  try {
    dailyRoom = await createDailyRoom(stream.id);
    await supabase.from('streams').update({
      daily_room_url: dailyRoom.url,
      daily_room_name: dailyRoom.name,
    }).eq('id', stream.id);
  } catch (err) {
    console.error('Daily.co room creation failed:', err.message);
    // Don't fail the whole request — stream can still work via WebRTC fallback
  }

  res.status(201).json({
    success: true,
    stream: {
      ...stream,
      daily_room_url: dailyRoom?.url,
    },
  });
});

// ============================================================
// PATCH /api/streams/:id/end
// Seller ends their stream
// ============================================================
router.patch('/:id/end', authenticate, sellerOnly, async (req, res) => {
  // Verify this stream belongs to the seller
  const { data: stream } = await supabase
    .from('streams')
    .select('seller_id')
    .eq('id', req.params.id)
    .single();

  if (!stream || stream.seller_id !== req.user.id) {
    return res.status(403).json({ error: 'Not your stream.' });
  }

  const { error } = await supabase
    .from('streams')
    .update({ status: 'ended', ended_at: new Date().toISOString() })
    .eq('id', req.params.id);

  if (error) return res.status(500).json({ error: 'Failed to end stream.' });

  res.json({ success: true, message: 'Stream ended.' });
});

// ============================================================
// POST /api/streams/:id/products
// Pin a product to the stream (max 3)
// ============================================================
router.post('/:id/products', authenticate, sellerOnly, async (req, res) => {
  const schema = Joi.object({
    name: Joi.string().min(2).max(200).required(),
    description: Joi.string().max(500),
    price: Joi.number().min(100).required(),  // min ₦1
    image_url: Joi.string().uri(),
    stock: Joi.number().min(1).default(999),
    position: Joi.number().valid(1, 2, 3).default(1),
  });

  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  // Verify stream ownership
  const { data: stream } = await supabase
    .from('streams')
    .select('seller_id, status')
    .eq('id', req.params.id)
    .single();

  if (!stream || stream.seller_id !== req.user.id) {
    return res.status(403).json({ error: 'Not your stream.' });
  }

  if (stream.status !== 'live') {
    return res.status(400).json({ error: 'Stream is not live.' });
  }

  // Deactivate existing product at this position
  await supabase
    .from('stream_products')
    .update({ is_active: false })
    .eq('stream_id', req.params.id)
    .eq('position', value.position);

  // Add new product (convert price to kobo)
  const { data: product, error: dbError } = await supabase
    .from('stream_products')
    .insert({
      stream_id: req.params.id,
      ...value,
      price: value.price * 100,  // convert naira to kobo
    })
    .select()
    .single();

  if (dbError) return res.status(500).json({ error: 'Failed to pin product.' });

  res.status(201).json({ success: true, product });
});

// ============================================================
// PATCH /api/streams/:streamId/viewer-count
// Update viewer count (called by Daily.co webhook or frontend)
// ============================================================
router.patch('/:id/viewer-count', async (req, res) => {
  const { count } = req.body;

  const { data: stream } = await supabase
    .from('streams')
    .select('peak_viewers')
    .eq('id', req.params.id)
    .single();

  await supabase.from('streams').update({
    viewer_count: count,
    peak_viewers: Math.max(stream?.peak_viewers || 0, count),
  }).eq('id', req.params.id);

  res.json({ success: true });
});

// ============================================================
// GET /api/streams/:id
// Get single stream details
// ============================================================
router.get('/:id', async (req, res) => {
  const { data: stream, error } = await supabase
    .from('streams')
    .select(`
      *,
      seller:users!seller_id(id, name, avatar_url),
      seller_profile:seller_profiles!inner(business_name, trust_score, followers_count),
      products:stream_products(id, name, price, image_url, stock, position, is_active)
    `)
    .eq('id', req.params.id)
    .single();

  if (error || !stream) return res.status(404).json({ error: 'Stream not found.' });

  res.json({ stream });
});

module.exports = router;
