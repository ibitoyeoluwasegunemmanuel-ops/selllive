// routes/sellers.js — Seller dashboard & profiles
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// GET /api/sellers/dashboard — seller's stats
router.get('/dashboard', authenticate, sellerOnly, async (req, res) => {
  const sellerId = req.user.id;
  const today = new Date().toISOString().split('T')[0];

  // Get seller profile
  const { data: profile } = await supabase
    .from('seller_profiles')
    .select('*')
    .eq('user_id', sellerId)
    .single();

  // Today's sales
  const { data: todayOrders } = await supabase
    .from('orders')
    .select('total_amount')
    .eq('seller_id', sellerId)
    .eq('status', 'paid')
    .gte('paid_at', `${today}T00:00:00.000Z`);

  const todayRevenue = todayOrders?.reduce((sum, o) => sum + o.total_amount, 0) || 0;

  // Pending orders (need seller action)
  const { data: pendingOrders } = await supabase
    .from('orders')
    .select(`
      id, order_ref, quantity, total_amount, status, created_at,
      product:stream_products(name, image_url),
      buyer:users!buyer_id(name, phone)
    `)
    .eq('seller_id', sellerId)
    .in('status', ['paid', 'processing'])
    .order('created_at', { ascending: false })
    .limit(10);

  // Recent streams
  const { data: recentStreams } = await supabase
    .from('streams')
    .select('id, title, status, viewer_count, total_orders, started_at, ended_at')
    .eq('seller_id', sellerId)
    .order('created_at', { ascending: false })
    .limit(5);

  res.json({
    profile,
    stats: {
      today_revenue_naira: todayRevenue / 100,
      followers: profile?.followers_count || 0,
      trust_score: profile?.trust_score || 5.0,
      total_sales: profile?.total_sales || 0,
      wallet_balance_naira: (profile?.total_earnings || 0) / 100,
    },
    pending_orders: pendingOrders || [],
    recent_streams: recentStreams || [],
  });
});

// GET /api/sellers/:id — public seller profile
router.get('/:id', async (req, res) => {
  const { data: seller } = await supabase
    .from('users')
    .select(`
      id, name, avatar_url,
      seller_profile:seller_profiles(business_name, bio, followers_count, total_sales)
    `)
    .eq('id', req.params.id)
    .eq('role', 'seller')
    .single();

  if (!seller) return res.status(404).json({ error: 'Seller not found.' });
  res.json({ seller });
});

// POST /api/sellers/:id/follow — follow/unfollow
router.post('/:id/follow', authenticate, async (req, res) => {
  const sellerId = req.params.id;
  const followerId = req.user.id;

  if (followerId === sellerId) {
    return res.status(400).json({ error: 'You cannot follow yourself.' });
  }

  // Check if already following
  const { data: existing } = await supabase
    .from('follows')
    .select('follower_id')
    .eq('follower_id', followerId)
    .eq('seller_id', sellerId)
    .single();

  if (existing) {
    // Unfollow
    await supabase.from('follows')
      .delete()
      .eq('follower_id', followerId)
      .eq('seller_id', sellerId);
    return res.json({ success: true, following: false });
  } else {
    // Follow
    await supabase.from('follows').insert({ follower_id: followerId, seller_id: sellerId });
    return res.json({ success: true, following: true });
  }
});

module.exports = router;
