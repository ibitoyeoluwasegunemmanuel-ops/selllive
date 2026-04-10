// routes/streams.js — Live stream management
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// GET /api/streams/active — all active streams
router.get('/active', async (req, res) => {
  const { data, error } = await supabase
    .from('streams')
    .select(`id, title, mode, viewer_count, pinned_product_id, seller_id,
      users!seller_id(name),
      seller_profiles!seller_id(business_name, is_verified, followers_count)`)
    .eq('status', 'live')
    .order('viewer_count', { ascending: false });
  res.json({ streams: data || [] });
});

// POST /api/streams/start — start a live session
router.post('/start', authenticate, sellerOnly, async (req, res) => {
  const { title, mode = 'product' } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  // End any existing live session for this seller
  await supabase.from('streams').update({ status: 'ended', ended_at: new Date().toISOString() })
    .eq('seller_id', req.user.id).eq('status', 'live');
  const { data, error } = await supabase.from('streams')
    .insert({ seller_id: req.user.id, title, mode, status: 'live', viewer_count: 0, started_at: new Date().toISOString() })
    .select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true, stream: data });
});

// POST /api/streams/pin-product — pin product during live
router.post('/pin-product', authenticate, async (req, res) => {
  const { product_id } = req.body;
  const { error } = await supabase.from('streams')
    .update({ pinned_product_id: product_id, updated_at: new Date().toISOString() })
    .eq('seller_id', req.user.id).eq('status', 'live');
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// POST /api/streams/end — end live session
router.post('/end', authenticate, async (req, res) => {
  await supabase.from('streams').update({ status: 'ended', ended_at: new Date().toISOString() })
    .eq('seller_id', req.user.id).eq('status', 'live');
  res.json({ success: true });
});

// PATCH /api/streams/:id/viewers — update viewer count
router.patch('/:id/viewers', async (req, res) => {
  const { count } = req.body;
  await supabase.from('streams').update({ viewer_count: count }).eq('id', req.params.id);
  res.json({ success: true });
});

module.exports = router;
