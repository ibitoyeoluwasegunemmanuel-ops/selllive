// routes/features.js — Flash Sales, Referrals, Addresses, Disputes, Analytics
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, sellerOnly, adminOnly } = require('../middleware/auth');

// ============================================================
// ===== FLASH SALES ===========================================
// ============================================================

// GET /api/features/flash-sales — active flash sales
router.get('/flash-sales', async (req, res) => {
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('flash_sales')
    .select(`
      id, title, description, discount_percent, starts_at, ends_at,
      seller:users!seller_id(id, name, avatar_url),
      seller_profile:seller_profiles!user_id(business_name),
      products:flash_sale_products(id, name, original_price, sale_price, image_url, stock, sold)
    `)
    .eq('is_active', true)
    .lte('starts_at', now)
    .gte('ends_at', now)
    .order('ends_at', { ascending: true });

  res.json({ flash_sales: data || [] });
});

// POST /api/features/flash-sales — create flash sale (seller)
router.post('/flash-sales', authenticate, sellerOnly, async (req, res) => {
  const { title, description, discount_percent, starts_at, ends_at, products } = req.body;

  if (!title || !discount_percent || !ends_at || !products?.length) {
    return res.status(400).json({ error: 'title, discount_percent, ends_at, and products required.' });
  }

  const { data: sale, error } = await supabase
    .from('flash_sales')
    .insert({
      seller_id: req.user.id,
      title, description, discount_percent,
      starts_at: starts_at || new Date().toISOString(),
      ends_at,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: 'Failed to create flash sale.' });

  // Add products
  await supabase.from('flash_sale_products').insert(
    products.map(p => ({
      flash_sale_id: sale.id,
      name: p.name,
      original_price: Math.round(p.original_price * 100),
      sale_price: Math.round(p.original_price * (1 - discount_percent / 100) * 100),
      image_url: p.image_url,
      stock: p.stock || 10,
    }))
  );

  res.status(201).json({ success: true, sale_id: sale.id });
});

// ============================================================
// ===== REFERRALS =============================================
// ============================================================

// GET /api/features/referral — get my referral code & earnings
router.get('/referral', authenticate, async (req, res) => {
  const { data: user } = await supabase
    .from('users')
    .select('referral_code')
    .eq('id', req.user.id)
    .single();

  const { data: referrals } = await supabase
    .from('referrals')
    .select(`
      id, status, reward_amount, created_at, qualified_at,
      referred:users!referred_id(name, phone, role)
    `)
    .eq('referrer_id', req.user.id)
    .order('created_at', { ascending: false });

  const totalEarned = (referrals || [])
    .filter(r => r.status === 'paid')
    .reduce((sum, r) => sum + (r.reward_amount || 0), 0);

  const pending = (referrals || []).filter(r => r.status === 'pending').length;
  const qualified = (referrals || []).filter(r => r.status === 'qualified').length;

  res.json({
    referral_code: user?.referral_code,
    referral_link: `https://selllive.ng/join?ref=${user?.referral_code}`,
    whatsapp_share_text: `Join SellLive — Nigeria's live commerce platform! 🔴\n\nSell from your phone, go live, earn money.\n\nJoin with my link and we both earn ₦500:\nhttps://selllive.ng/join?ref=${user?.referral_code}`,
    stats: {
      total_referrals: (referrals || []).length,
      pending,
      qualified,
      total_earned_naira: totalEarned / 100,
    },
    referrals: referrals || [],
  });
});

// POST /api/features/referral/apply — apply referral code at registration
router.post('/referral/apply', authenticate, async (req, res) => {
  const { referral_code } = req.body;
  if (!referral_code) return res.status(400).json({ error: 'referral_code required.' });

  // Find referrer
  const { data: referrer } = await supabase
    .from('users')
    .select('id')
    .eq('referral_code', referral_code.toUpperCase())
    .single();

  if (!referrer) return res.status(404).json({ error: 'Invalid referral code.' });
  if (referrer.id === req.user.id) return res.status(400).json({ error: 'Cannot refer yourself.' });

  // Create referral record
  const { error } = await supabase.from('referrals').insert({
    referrer_id: referrer.id,
    referred_id: req.user.id,
    referral_code,
    status: 'pending',
  }).onConflict(['referrer_id', 'referred_id']).ignore();

  // Update user's referred_by
  await supabase.from('users').update({ referred_by: referrer.id }).eq('id', req.user.id);

  res.json({ success: true, message: 'Referral applied! Your referrer earns ₦500 when you make your first sale.' });
});

// ============================================================
// ===== ADDRESS BOOK ==========================================
// ============================================================

// GET /api/features/addresses
router.get('/addresses', authenticate, async (req, res) => {
  const { data, error } = await supabase
    .from('delivery_addresses')
    .select('*')
    .eq('user_id', req.user.id)
    .order('is_default', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch addresses.' });
  res.json({ addresses: data || [] });
});

// POST /api/features/addresses
router.post('/addresses', authenticate, async (req, res) => {
  const { label, full_address, phone, is_default } = req.body;
  if (!full_address || !phone) return res.status(400).json({ error: 'full_address and phone required.' });

  // If setting as default, unset others
  if (is_default) {
    await supabase.from('delivery_addresses')
      .update({ is_default: false })
      .eq('user_id', req.user.id);
  }

  const { data, error } = await supabase
    .from('delivery_addresses')
    .insert({ user_id: req.user.id, label: label || 'Home', full_address, phone, is_default: is_default || false })
    .select()
    .single();

  if (error) return res.status(500).json({ error: 'Failed to save address.' });
  res.status(201).json({ address: data });
});

// DELETE /api/features/addresses/:id
router.delete('/addresses/:id', authenticate, async (req, res) => {
  await supabase.from('delivery_addresses')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);
  res.json({ success: true });
});

// ============================================================
// ===== DISPUTES ==============================================
// ============================================================

// POST /api/features/disputes — open a dispute
router.post('/disputes', authenticate, async (req, res) => {
  const { order_id, reason, description } = req.body;
  if (!order_id || !reason || !description) {
    return res.status(400).json({ error: 'order_id, reason, and description required.' });
  }

  const { data: order } = await supabase
    .from('orders')
    .select('seller_id, buyer_id, status')
    .eq('id', order_id)
    .single();

  if (!order) return res.status(404).json({ error: 'Order not found.' });
  if (order.buyer_id !== req.user.id) return res.status(403).json({ error: 'Only buyer can open dispute.' });
  if (!['paid', 'processing', 'shipped', 'delivered'].includes(order.status)) {
    return res.status(400).json({ error: 'Can only dispute paid orders.' });
  }

  const { data: dispute, error } = await supabase
    .from('disputes')
    .insert({
      order_id,
      buyer_id: req.user.id,
      seller_id: order.seller_id,
      reason, description,
      status: 'open',
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: 'Failed to open dispute.' });
  res.status(201).json({ success: true, dispute_id: dispute.id, message: 'Dispute opened. Admin will review within 24 hours.' });
});

// GET /api/features/disputes — get my disputes
router.get('/disputes', authenticate, async (req, res) => {
  const { data, error } = await supabase
    .from('disputes')
    .select(`
      id, reason, description, status, admin_notes, resolution, opened_at, resolved_at,
      order:orders!order_id(order_ref, total_amount, status)
    `)
    .or(`buyer_id.eq.${req.user.id},seller_id.eq.${req.user.id}`)
    .order('opened_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch disputes.' });
  res.json({ disputes: data || [] });
});

// ============================================================
// ===== SELLER ANALYTICS ======================================
// ============================================================

// GET /api/features/analytics — seller dashboard analytics
router.get('/analytics', authenticate, sellerOnly, async (req, res) => {
  const sellerId = req.user.id;
  const now = new Date();
  const last7days = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const last30days = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const [
    { data: allOrders },
    { data: recentOrders },
    { data: streams },
    { data: posts },
    { data: topProducts },
    { data: wallet },
  ] = await Promise.all([
    supabase.from('orders').select('total_amount, commission, created_at, status').eq('seller_id', sellerId).eq('status', 'paid'),
    supabase.from('orders').select('total_amount, created_at').eq('seller_id', sellerId).eq('status', 'paid').gte('created_at', last30days),
    supabase.from('streams').select('viewer_count, total_orders, started_at, ended_at').eq('seller_id', sellerId).order('created_at', { ascending: false }).limit(30),
    supabase.from('posts').select('like_count, comment_count, view_count, created_at').eq('seller_id', sellerId),
    supabase.from('orders').select('product_id, total_amount').eq('seller_id', sellerId).eq('status', 'paid').limit(100),
    supabase.from('wallets').select('balance, total_earned, total_withdrawn').eq('seller_id', sellerId).single(),
  ]);

  // Revenue by day (last 7 days)
  const revenueByDay = {};
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const key = d.toISOString().split('T')[0];
    revenueByDay[key] = 0;
  }
  (recentOrders || []).forEach(o => {
    const day = o.created_at?.split('T')[0];
    if (day in revenueByDay) revenueByDay[day] += (o.total_amount || 0) / 100;
  });

  // Best performing streams
  const avgViewers = streams?.length
    ? (streams.reduce((s, st) => s + (st.viewer_count || 0), 0) / streams.length).toFixed(0)
    : 0;

  // Post engagement
  const totalPostViews = (posts || []).reduce((s, p) => s + (p.view_count || 0), 0);
  const totalPostLikes = (posts || []).reduce((s, p) => s + (p.like_count || 0), 0);

  res.json({
    summary: {
      total_revenue_naira: (allOrders || []).reduce((s, o) => s + (o.total_amount || 0), 0) / 100,
      total_commission_paid_naira: (allOrders || []).reduce((s, o) => s + (o.commission || 0), 0) / 100,
      total_orders: (allOrders || []).length,
      wallet_balance_naira: (wallet.data?.balance || 0) / 100,
    },
    revenue_chart: Object.entries(revenueByDay).map(([date, amount]) => ({ date, amount })),
    streams: {
      total: streams?.length || 0,
      avg_viewers: Number(avgViewers),
      best_stream: streams?.[0] || null,
    },
    posts: {
      total: posts?.length || 0,
      total_views: totalPostViews,
      total_likes: totalPostLikes,
      engagement_rate: totalPostViews > 0 ? ((totalPostLikes / totalPostViews) * 100).toFixed(1) : '0',
    },
  });
});

module.exports = router;
