// routes/feed.js — Shop Feed (TikTok/Instagram style product posts)
const express = require('express');
const router = express.Router();
const axios = require('axios');
const Joi = require('joi');
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

const COMMISSION = Number(process.env.COMMISSION_PERCENT || 10) / 100;

// ============================================================
// GET /api/feed
// Main scrollable feed — latest posts from all sellers
// For logged-in users: prioritises posts from followed sellers
// ============================================================
router.get('/', async (req, res) => {
  const { page = 1, limit = 10 } = req.query;
  const offset = (page - 1) * limit;

  const { data: posts, error } = await supabase
    .from('posts')
    .select(`
      id, caption, media_url, media_type, thumbnail_url,
      duration_secs, like_count, comment_count, share_count, view_count, created_at, seller_id,
      products:post_products(id, name, price, image_url, stock, position)
    `)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .range(offset, offset + Number(limit) - 1);

  if (error) return res.status(500).json({ error: 'Failed to fetch feed.' });
  
  // Enrich with seller info
  const enriched = await Promise.all((posts || []).map(async (post) => {
    const { data: seller } = await supabase.from('users').select('id, name, avatar_url').eq('id', post.seller_id).single();
    const { data: profile } = await supabase.from('seller_profiles').select('business_name, is_verified').eq('user_id', post.seller_id).single();
    return { ...post, seller, seller_profile: profile };
  }));
  
  res.json({ posts: enriched, page: Number(page) });
});

// ============================================================
// GET /api/feed/seller/:sellerId
// All posts by a specific seller (their profile grid)
// ============================================================
router.get('/seller/:sellerId', async (req, res) => {
  const { data: posts, error } = await supabase
    .from('posts')
    .select(`
      id, media_url, media_type, thumbnail_url,
      like_count, comment_count, view_count, created_at,
      products:post_products(id, name, price)
    `)
    .eq('seller_id', req.params.sellerId)
    .eq('is_active', true)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch posts.' });
  res.json({ posts: posts || [] });
});

// ============================================================
// POST /api/feed
// Create a new post (seller only)
// ============================================================
router.post('/', authenticate, sellerOnly, async (req, res) => {
  const schema = Joi.object({
    caption: Joi.string().max(500),
    media_url: Joi.string().uri().required(),
    media_type: Joi.string().valid('video', 'image').required(),
    thumbnail_url: Joi.string().uri(),
    duration_secs: Joi.number().min(1).max(60),
    products: Joi.array().items(Joi.object({
      name: Joi.string().required(),
      price: Joi.number().min(100).required(),  // in naira
      image_url: Joi.string().uri(),
      stock: Joi.number().default(999),
      position: Joi.number().default(1),
    })).max(5),
  });

  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { products, ...postData } = value;

  // Create post
  const { data: post, error: postError } = await supabase
    .from('posts')
    .insert({ seller_id: req.user.id, ...postData })
    .select()
    .single();

  if (postError) return res.status(500).json({ error: 'Failed to create post.' });

  // Add tagged products
  if (products?.length) {
    await supabase.from('post_products').insert(
      products.map((p, i) => ({
        post_id: post.id,
        name: p.name,
        price: Math.round(p.price * 100),  // convert naira to kobo
        image_url: p.image_url,
        stock: p.stock || 999,
        position: p.position || i + 1,
      }))
    );
  }

  res.status(201).json({ success: true, post });
});

// ============================================================
// DELETE /api/feed/:id
// Delete own post
// ============================================================
router.delete('/:id', authenticate, sellerOnly, async (req, res) => {
  const { data: post } = await supabase
    .from('posts')
    .select('seller_id')
    .eq('id', req.params.id)
    .single();

  if (!post || post.seller_id !== req.user.id) {
    return res.status(403).json({ error: 'Not your post.' });
  }

  await supabase.from('posts').update({ is_active: false }).eq('id', req.params.id);
  res.json({ success: true });
});

// ============================================================
// POST /api/feed/:id/like
// Like or unlike a post (toggle)
// ============================================================
router.post('/:id/like', authenticate, async (req, res) => {
  const postId = req.params.id;
  const userId = req.user.id;

  // Check if already liked
  const { data: existing } = await supabase
    .from('post_likes')
    .select('post_id')
    .eq('post_id', postId)
    .eq('user_id', userId)
    .single();

  if (existing) {
    await supabase.from('post_likes').delete()
      .eq('post_id', postId).eq('user_id', userId);
    return res.json({ liked: false });
  } else {
    await supabase.from('post_likes').insert({ post_id: postId, user_id: userId });
    return res.json({ liked: true });
  }
});

// ============================================================
// GET /api/feed/:id/comments
// Get comments on a post
// ============================================================
router.get('/:id/comments', async (req, res) => {
  const { data: comments, error } = await supabase
    .from('post_comments')
    .select(`
      id, comment, created_at,
      user:users!user_id(id, name, avatar_url)
    `)
    .eq('post_id', req.params.id)
    .order('created_at', { ascending: true })
    .limit(50);

  if (error) return res.status(500).json({ error: 'Failed to fetch comments.' });
  res.json({ comments: comments || [] });
});

// ============================================================
// POST /api/feed/:id/comment
// Add a comment
// ============================================================
router.post('/:id/comment', authenticate, async (req, res) => {
  const { comment } = req.body;
  if (!comment?.trim()) return res.status(400).json({ error: 'Comment cannot be empty.' });
  if (comment.length > 300) return res.status(400).json({ error: 'Comment too long (max 300 chars).' });

  const { data: newComment, error } = await supabase
    .from('post_comments')
    .insert({ post_id: req.params.id, user_id: req.user.id, comment: comment.trim() })
    .select(`id, comment, created_at, user:users!user_id(id, name, avatar_url)`)
    .single();

  if (error) return res.status(500).json({ error: 'Failed to add comment.' });
  res.status(201).json({ success: true, comment: newComment });
});

// ============================================================
// POST /api/feed/:postId/buy
// Buy a product from a feed post
// ============================================================
router.post('/:postId/buy', authenticate, async (req, res) => {
  const { product_id, quantity = 1, delivery_address, delivery_phone } = req.body;
  if (!product_id) return res.status(400).json({ error: 'product_id required.' });

  // Get product
  const { data: product } = await supabase
    .from('post_products')
    .select('*, post:posts!post_id(seller_id)')
    .eq('id', product_id)
    .eq('post_id', req.params.postId)
    .single();

  if (!product) return res.status(404).json({ error: 'Product not found.' });
  if (product.stock < quantity) return res.status(400).json({ error: `Only ${product.stock} left.` });

  const totalAmount = product.price * quantity;
  const commission = Math.floor(totalAmount * COMMISSION);
  const sellerPayout = totalAmount - commission;

  // Get buyer info
  const { data: buyer } = await supabase
    .from('users')
    .select('name, phone, email')
    .eq('id', req.user.id)
    .single();

  // Create order
  const { data: order, error: orderError } = await supabase
    .from('post_orders')
    .insert({
      post_id: req.params.postId,
      post_product_id: product_id,
      buyer_id: req.user.id,
      seller_id: product.post.seller_id,
      quantity,
      unit_price: product.price,
      total_amount: totalAmount,
      commission,
      seller_payout: sellerPayout,
      delivery_address,
      delivery_phone: delivery_phone || buyer?.phone,
      status: 'payment_initiated',
    })
    .select()
    .single();

  if (orderError) return res.status(500).json({ error: 'Failed to create order.' });

  // Create Flutterwave payment link
  const flwTxRef = `SLP-${order.id.split('-')[0]}-${Date.now()}`;
  const amountNaira = totalAmount / 100;

  try {
    const flwResponse = await axios.post(
      'https://api.flutterwave.com/v3/payments',
      {
        tx_ref: flwTxRef,
        amount: amountNaira,
        currency: 'NGN',
        redirect_url: `${process.env.APP_URL}/payment/callback?order_id=${order.id}&type=post`,
        meta: { order_id: order.id, type: 'post_order' },
        customer: {
          email: buyer?.email || `${req.user.id}@selllive.ng`,
          phonenumber: buyer?.phone,
          name: buyer?.name,
        },
        customizations: {
          title: 'SellLive Shop',
          description: `${product.name} x${quantity}`,
        },
      },
      { headers: { Authorization: `Bearer ${process.env.FLW_SECRET_KEY}` } }
    );

    const paymentUrl = flwResponse.data.data.link;
    await supabase.from('post_orders').update({ flw_tx_ref: flwTxRef, payment_url: paymentUrl }).eq('id', order.id);
    await supabase.from('post_products').update({ stock: product.stock - quantity }).eq('id', product_id);

    res.json({
      success: true,
      order_id: order.id,
      order_ref: order.order_ref,
      payment_url: paymentUrl,
      amount: amountNaira,
    });
  } catch (flwErr) {
    await supabase.from('post_orders').update({ status: 'cancelled' }).eq('id', order.id);
    // Return order without payment link (can pay later)
    res.json({
      success: true,
      order_id: order.id,
      order_ref: order.order_ref,
      payment_url: null,
      message: 'Order created. Contact seller to pay.',
    });
  }
});

// ============================================================
// PATCH /api/feed/:id/view
// Increment view count (called when post enters viewport)
// ============================================================
router.patch('/:id/view', async (req, res) => {
  await supabase.rpc('increment_post_views', { post_id: req.params.id });
  res.json({ success: true });
});

module.exports = router;
