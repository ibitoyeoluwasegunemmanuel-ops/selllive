// routes/orders.js — Order management
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// GET /api/orders — buyer sees their orders
router.get('/', authenticate, async (req, res) => {
  const { data: orders, error } = await supabase
    .from('orders')
    .select(`
      id, order_ref, quantity, total_amount, status, created_at, paid_at, delivered_at,
      product:stream_products(name, image_url, price),
      seller:users!seller_id(name, avatar_url),
      seller_profile:seller_profiles(business_name)
    `)
    .eq('buyer_id', req.user.id)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch orders.' });

  res.json({ orders });
});

// PATCH /api/orders/:id/status — seller updates order status
router.patch('/:id/status', authenticate, sellerOnly, async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['processing', 'shipped', 'delivered'];

  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: `Status must be one of: ${validStatuses.join(', ')}` });
  }

  const { data: order } = await supabase
    .from('orders')
    .select('seller_id')
    .eq('id', req.params.id)
    .single();

  if (!order || order.seller_id !== req.user.id) {
    return res.status(403).json({ error: 'Not your order.' });
  }

  const updates = { status };
  if (status === 'delivered') updates.delivered_at = new Date().toISOString();

  await supabase.from('orders').update(updates).eq('id', req.params.id);
  res.json({ success: true, status });
});

module.exports = router;
