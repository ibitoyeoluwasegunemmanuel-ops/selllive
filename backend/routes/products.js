// routes/products.js — Seller product catalog management
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// GET /api/products/my — seller's own product catalog
router.get('/my', authenticate, sellerOnly, async (req, res) => {
  const { data, error } = await supabase
    .from('stream_products')
    .select('*')
    .eq('seller_id', req.user.id)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch products.' });
  res.json({ products: data || [] });
});

// POST /api/products — create a product
router.post('/', authenticate, sellerOnly, async (req, res) => {
  const { name, description, price, stock, image_url, weight_kg, stream_id } = req.body;
  if (!name || !price) return res.status(400).json({ error: 'name and price are required.' });
  if (price < 1) return res.status(400).json({ error: 'Price must be at least ₦1.' });

  const { data, error } = await supabase
    .from('stream_products')
    .insert({
      seller_id: req.user.id,
      stream_id: stream_id || null,
      name: name.trim(),
      description,
      price: Math.round(price), // store in kobo
      stock: stock || 999,
      image_url,
      weight_kg: weight_kg || 0.5,
      is_active: true,
      is_pinned: false,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: 'Failed to create product.' });
  res.status(201).json({ success: true, product: data });
});

// PATCH /api/products/:id — update a product
router.patch('/:id', authenticate, sellerOnly, async (req, res) => {
  const { name, description, price, stock, image_url, is_active, is_pinned } = req.body;

  // Verify ownership
  const { data: existing } = await supabase
    .from('stream_products').select('seller_id').eq('id', req.params.id).single();
  if (!existing) return res.status(404).json({ error: 'Product not found.' });
  if (existing.seller_id !== req.user.id) return res.status(403).json({ error: 'Not your product.' });

  const updates = {};
  if (name !== undefined)       updates.name       = name.trim();
  if (description !== undefined) updates.description = description;
  if (price !== undefined)      updates.price      = Math.round(price);
  if (stock !== undefined)      updates.stock      = stock;
  if (image_url !== undefined)  updates.image_url  = image_url;
  if (is_active !== undefined)  updates.is_active  = is_active;
  if (is_pinned !== undefined)  updates.is_pinned  = is_pinned;

  const { data, error } = await supabase
    .from('stream_products').update(updates).eq('id', req.params.id).select().single();
  if (error) return res.status(500).json({ error: 'Failed to update product.' });
  res.json({ success: true, product: data });
});

// DELETE /api/products/:id — soft delete (set inactive)
router.delete('/:id', authenticate, sellerOnly, async (req, res) => {
  const { data: existing } = await supabase
    .from('stream_products').select('seller_id').eq('id', req.params.id).single();
  if (!existing) return res.status(404).json({ error: 'Product not found.' });
  if (existing.seller_id !== req.user.id) return res.status(403).json({ error: 'Not your product.' });

  await supabase.from('stream_products').update({ is_active: false }).eq('id', req.params.id);
  res.json({ success: true, message: 'Product removed.' });
});


// GET /api/products/:id — single product detail (public)
router.get('/:id', async (req, res) => {
  const { data, error } = await supabase
    .from('stream_products')
    .select('*, seller_profiles!seller_id(business_name, is_verified, followers_count, whatsapp, description, total_sales, rating)')
    .eq('id', req.params.id)
    .single();
  if (error || !data) return res.status(404).json({ error: 'Product not found' });
  // Get seller user info
  const { data: seller } = await supabase.from('users').select('name, avatar_url').eq('id', data.seller_id).single();
  res.json({ product: { ...data, seller } });
});

// POST /api/products/:id/pin — pin product to active stream
router.post('/:id/pin', authenticate, sellerOnly, async (req, res) => {
  const { stream_id } = req.body;
  if (!stream_id) return res.status(400).json({ error: 'stream_id required.' });

  // Verify product belongs to seller
  const { data: product } = await supabase
    .from('stream_products').select('seller_id').eq('id', req.params.id).single();
  if (!product || product.seller_id !== req.user.id) return res.status(403).json({ error: 'Not your product.' });

  // Unpin all others for this stream
  await supabase.from('stream_products')
    .update({ is_pinned: false })
    .eq('stream_id', stream_id)
    .eq('seller_id', req.user.id);

  // Pin this one and assign to stream
  await supabase.from('stream_products')
    .update({ is_pinned: true, stream_id })
    .eq('id', req.params.id);

  res.json({ success: true, message: 'Product pinned to stream.' });
});

module.exports = router;
