// routes/reviews.js — Product reviews after delivery
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// POST /api/reviews — leave a review
router.post('/', authenticate, async (req, res) => {
  const { order_id, rating, comment, photo_url } = req.body;
  if (!order_id || !rating) return res.status(400).json({ error: 'order_id and rating required.' });

  const { data: order } = await supabase.from('orders').select('buyer_id, seller_id, status')
    .eq('id', order_id).single();

  if (!order) return res.status(404).json({ error: 'Order not found.' });
  if (order.buyer_id !== req.user.id) return res.status(403).json({ error: 'Only buyer can review.' });
  if (!['delivered', 'completed'].includes(order.status)) return res.status(400).json({ error: 'Can only review delivered orders.' });

  const { data: review, error } = await supabase.from('reviews')
    .upsert({ order_id, buyer_id: req.user.id, seller_id: order.seller_id, rating, comment, photo_url },
      { onConflict: 'order_id,buyer_id' })
    .select().single();

  if (error) return res.status(500).json({ error: 'Failed to save review.' });

  await supabase.from('notifications').insert({
    user_id: order.seller_id, type: 'new_review',
    title: `⭐ New ${rating}-star review!`,
    body: comment || 'A buyer left you a review',
    data: { order_id, rating },
  });

  res.json({ success: true, review });
});

// GET /api/reviews/seller/:id
router.get('/seller/:id', async (req, res) => {
  const { data, error } = await supabase.from('reviews')
    .select('id, rating, comment, photo_url, created_at, buyer:users!buyer_id(name, avatar_url)')
    .eq('seller_id', req.params.id).order('created_at', { ascending: false }).limit(20);
  if (error) return res.status(500).json({ error: 'Failed to fetch reviews.' });
  res.json({ reviews: data || [] });
});

module.exports = router;

// GET /api/reviews/seller/:id — used by seller profile
router.get('/seller/:id/all', async (req, res) => {
  const { data, error } = await supabase.from('reviews')
    .select('id, rating, comment, photo_url, created_at, buyer:users!buyer_id(name, avatar_url)')
    .eq('seller_id', req.params.id).order('created_at', { ascending: false }).limit(30);
  if (error) return res.status(500).json({ error: 'Failed to fetch reviews.' });
  res.json({ reviews: data || [] });
});
