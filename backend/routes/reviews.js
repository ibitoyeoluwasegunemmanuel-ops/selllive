// routes/reviews.js — Product reviews & ratings
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// GET /api/reviews/product/:productId
router.get('/product/:productId', async (req, res) => {
  const { data, error } = await supabase
    .from('product_reviews')
    .select('id, rating, comment, reviewer_name, created_at')
    .eq('product_id', req.params.productId)
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) return res.status(500).json({ error: 'Failed to load reviews' });
  const reviews = data || [];
  const avg = reviews.length ? (reviews.reduce((s,r)=>s+r.rating,0)/reviews.length).toFixed(1) : 0;
  res.json({ reviews, avg_rating: parseFloat(avg), count: reviews.length });
});

// POST /api/reviews
router.post('/', authenticate, async (req, res) => {
  const { product_id, rating, comment, order_id } = req.body;
  if (!product_id || !rating) return res.status(400).json({ error: 'product_id and rating required' });
  if (rating < 1 || rating > 5) return res.status(400).json({ error: 'Rating must be 1-5' });
  const { data: user } = await supabase.from('users').select('name').eq('id', req.user.id).single();
  const { data, error } = await supabase.from('product_reviews')
    .upsert({ user_id: req.user.id, product_id, order_id: order_id||null, rating, comment: comment?.trim()||null, reviewer_name: user?.name||'Anonymous' }, { onConflict: 'user_id,product_id' })
    .select().single();
  if (error) return res.status(500).json({ error: 'Failed to submit review' });
  // Update avg
  const { data: all } = await supabase.from('product_reviews').select('rating').eq('product_id', product_id);
  if (all?.length) {
    const avg = all.reduce((s,r)=>s+r.rating,0)/all.length;
    await supabase.from('stream_products').update({ avg_rating: Math.round(avg*10)/10, review_count: all.length }).eq('id', product_id);
  }
  res.json({ success: true, review: data });
});

module.exports = router;
