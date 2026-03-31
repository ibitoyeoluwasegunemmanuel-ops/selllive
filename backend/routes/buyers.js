// routes/buyers.js
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// POST /api/buyers/review — leave a review after delivery
router.post('/review', authenticate, async (req, res) => {
  const { order_id, rating, comment } = req.body;

  if (!order_id || !rating) {
    return res.status(400).json({ error: 'order_id and rating required.' });
  }

  if (rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'Rating must be between 1 and 5.' });
  }

  // Verify order belongs to buyer and is delivered
  const { data: order } = await supabase
    .from('orders')
    .select('seller_id, status, buyer_id')
    .eq('id', order_id)
    .single();

  if (!order) return res.status(404).json({ error: 'Order not found.' });
  if (order.buyer_id !== req.user.id) return res.status(403).json({ error: 'Not your order.' });
  if (order.status !== 'delivered') return res.status(400).json({ error: 'You can only review delivered orders.' });

  const { error } = await supabase.from('reviews').insert({
    order_id,
    buyer_id: req.user.id,
    seller_id: order.seller_id,
    rating,
    comment,
  });

  if (error) {
    if (error.code === '23505') return res.status(400).json({ error: 'You already reviewed this order.' });
    return res.status(500).json({ error: 'Failed to save review.' });
  }

  res.json({ success: true, message: 'Review submitted. Thank you!' });
});

module.exports = router;
