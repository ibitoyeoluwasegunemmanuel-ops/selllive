// routes/cart.js — Shopping cart
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// GET /api/cart — get user's cart with product details
router.get('/', authenticate, async (req, res) => {
  const { data: items, error } = await supabase
    .from('cart_items')
    .select('id, quantity, product_id, created_at')
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to load cart' });

  // Enrich with product data
  const productIds = (items || []).map(i => i.product_id);
  let products = [];
  if (productIds.length) {
    const { data } = await supabase
      .from('stream_products')
      .select('id, name, price, stock, image_url, is_active')
      .in('id', productIds);
    products = data || [];
  }

  const enriched = (items || []).map(item => {
    const product = products.find(p => p.id === item.product_id);
    return { ...item, product };
  }).filter(i => i.product?.is_active !== false);

  const total = enriched.reduce((sum, i) => sum + (i.product?.price || 0) * i.quantity, 0);
  res.json({ items: enriched, total, count: enriched.length });
});

// POST /api/cart — add item to cart
router.post('/', authenticate, async (req, res) => {
  const { product_id, quantity = 1 } = req.body;
  if (!product_id) return res.status(400).json({ error: 'product_id required' });

  // Check product exists and has stock
  const { data: product } = await supabase
    .from('stream_products').select('id, name, price, stock').eq('id', product_id).single();
  if (!product) return res.status(404).json({ error: 'Product not found' });
  if (product.stock < 1) return res.status(400).json({ error: 'Product out of stock' });

  // Upsert cart item
  const { data, error } = await supabase
    .from('cart_items')
    .upsert({ user_id: req.user.id, product_id, quantity }, { onConflict: 'user_id,product_id' })
    .select().single();

  if (error) return res.status(500).json({ error: 'Failed to add to cart' });
  res.json({ success: true, item: data, message: `${product.name} added to cart` });
});

// PATCH /api/cart/:id — update quantity
router.patch('/:id', authenticate, async (req, res) => {
  const { quantity } = req.body;
  if (!quantity || quantity < 1) {
    // Remove item if qty 0
    await supabase.from('cart_items').delete().eq('id', req.params.id).eq('user_id', req.user.id);
    return res.json({ success: true, removed: true });
  }
  const { data, error } = await supabase
    .from('cart_items')
    .update({ quantity, updated_at: new Date().toISOString() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select().single();
  if (error) return res.status(500).json({ error: 'Failed to update cart' });
  res.json({ success: true, item: data });
});

// DELETE /api/cart/:id — remove single item
router.delete('/:id', authenticate, async (req, res) => {
  await supabase.from('cart_items').delete().eq('id', req.params.id).eq('user_id', req.user.id);
  res.json({ success: true });
});

// DELETE /api/cart — clear entire cart
router.delete('/', authenticate, async (req, res) => {
  await supabase.from('cart_items').delete().eq('user_id', req.user.id);
  res.json({ success: true, message: 'Cart cleared' });
});

module.exports = router;
