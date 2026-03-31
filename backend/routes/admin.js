// routes/admin.js — Admin-only endpoints
// All routes require authenticate + adminOnly middleware
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, adminOnly } = require('../middleware/auth');

// Apply admin guard to all routes in this file
router.use(authenticate, adminOnly);

// ============================================================
// GET /api/admin/stats
// Dashboard overview numbers
// ============================================================
router.get('/stats', async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];

    const [
      { count: totalOrders },
      { count: totalSellers },
      { count: totalBuyers },
      { count: liveStreams },
      { data: revenueData },
      { data: todayOrders },
      { count: pendingVerifications },
    ] = await Promise.all([
      supabase.from('orders').select('*', { count: 'exact', head: true }),
      supabase.from('users').select('*', { count: 'exact', head: true }).eq('role', 'seller'),
      supabase.from('users').select('*', { count: 'exact', head: true }).eq('role', 'buyer'),
      supabase.from('streams').select('*', { count: 'exact', head: true }).eq('status', 'live'),
      supabase.from('orders').select('total_amount, commission').eq('status', 'paid'),
      supabase.from('orders').select('total_amount, commission').eq('status', 'paid').gte('paid_at', `${today}T00:00:00Z`),
      supabase.from('seller_profiles').select('*', { count: 'exact', head: true }).eq('is_verified', false),
    ]);

    const totalRevenue = (revenueData || []).reduce((s, o) => s + (o.total_amount || 0), 0);
    const totalCommission = (revenueData || []).reduce((s, o) => s + (o.commission || 0), 0);
    const todayRevenue = (todayOrders || []).reduce((s, o) => s + (o.total_amount || 0), 0);

    res.json({
      total_orders: totalOrders || 0,
      total_sellers: totalSellers || 0,
      total_buyers: totalBuyers || 0,
      live_streams: liveStreams || 0,
      total_revenue_naira: totalRevenue / 100,
      total_commission_naira: totalCommission / 100,
      today_revenue_naira: todayRevenue / 100,
      pending_verifications: pendingVerifications || 0,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch stats.' });
  }
});

// ============================================================
// GET /api/admin/orders
// All orders across all sellers
// ============================================================
router.get('/orders', async (req, res) => {
  const { page = 1, limit = 20, status } = req.query;
  const offset = (page - 1) * limit;

  let query = supabase
    .from('orders')
    .select(`
      id, order_ref, quantity, total_amount, commission, status,
      created_at, paid_at, delivered_at,
      product:stream_products(name, image_url),
      buyer:users!buyer_id(name, phone),
      seller:users!seller_id(name),
      seller_profile:seller_profiles!seller_id(business_name)
    `)
    .order('created_at', { ascending: false })
    .range(offset, offset + Number(limit) - 1);

  if (status) query = query.eq('status', status);

  const { data: orders, error, count } = await query;
  if (error) return res.status(500).json({ error: 'Failed to fetch orders.' });

  res.json({ orders: orders || [], total: count, page: Number(page) });
});

// ============================================================
// GET /api/admin/sellers
// All sellers with their profiles
// ============================================================
router.get('/sellers', async (req, res) => {
  const { verified } = req.query;

  let query = supabase
    .from('users')
    .select(`
      id, name, phone, created_at,
      profile:seller_profiles(
        business_name, bio, trust_score, total_sales,
        total_earnings, followers_count, is_verified, bank_account
      )
    `)
    .eq('role', 'seller')
    .order('created_at', { ascending: false });

  const { data: sellers, error } = await query;
  if (error) return res.status(500).json({ error: 'Failed to fetch sellers.' });

  let result = sellers || [];
  if (verified === 'false') {
    result = result.filter(s => s.profile?.is_verified === false);
  } else if (verified === 'true') {
    result = result.filter(s => s.profile?.is_verified === true);
  }

  res.json({ sellers: result });
});

// ============================================================
// PATCH /api/admin/sellers/:id/verify
// Approve or reject a seller
// ============================================================
router.patch('/sellers/:id/verify', async (req, res) => {
  const { approved } = req.body;

  const { error } = await supabase
    .from('seller_profiles')
    .update({ is_verified: approved })
    .eq('user_id', req.params.id);

  if (error) return res.status(500).json({ error: 'Failed to update seller.' });

  res.json({
    success: true,
    message: approved ? 'Seller verified ✓' : 'Seller rejected',
  });
});

// ============================================================
// GET /api/admin/streams
// All streams (live + past)
// ============================================================
router.get('/streams', async (req, res) => {
  const { status = 'live' } = req.query;

  const { data: streams, error } = await supabase
    .from('streams')
    .select(`
      id, title, status, viewer_count, peak_viewers, total_orders,
      started_at, ended_at, created_at,
      seller:users!seller_id(name, phone),
      seller_profile:seller_profiles!seller_id(business_name)
    `)
    .eq('status', status)
    .order('viewer_count', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: 'Failed to fetch streams.' });
  res.json({ streams: streams || [] });
});

// ============================================================
// DELETE /api/admin/streams/:id
// Force-end a live stream
// ============================================================
router.delete('/streams/:id', async (req, res) => {
  const { error } = await supabase
    .from('streams')
    .update({ status: 'ended', ended_at: new Date().toISOString() })
    .eq('id', req.params.id);

  if (error) return res.status(500).json({ error: 'Failed to end stream.' });
  res.json({ success: true, message: 'Stream ended by admin.' });
});

// ============================================================
// GET /api/admin/commissions
// Platform commission summary
// ============================================================
router.get('/commissions', async (req, res) => {
  const { data, error } = await supabase
    .from('orders')
    .select(`
      commission, total_amount, created_at,
      seller_profile:seller_profiles!seller_id(business_name)
    `)
    .eq('status', 'paid')
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch commissions.' });

  // Group by seller
  const bySellerMap = {};
  (data || []).forEach(o => {
    const name = o.seller_profile?.business_name || 'Unknown';
    if (!bySellerMap[name]) {
      bySellerMap[name] = { business_name: name, orders: 0, gross: 0, commission: 0 };
    }
    bySellerMap[name].orders++;
    bySellerMap[name].gross += o.total_amount;
    bySellerMap[name].commission += o.commission;
  });

  const bySeller = Object.values(bySellerMap).sort((a, b) => b.commission - a.commission);
  const totalCommission = bySeller.reduce((s, r) => s + r.commission, 0);

  res.json({
    total_commission_naira: totalCommission / 100,
    by_seller: bySeller.map(r => ({
      ...r,
      gross_naira: r.gross / 100,
      commission_naira: r.commission / 100,
      seller_payout_naira: (r.gross - r.commission) / 100,
    })),
  });
});

// ============================================================
// GET /api/admin/buyers
// All buyers
// ============================================================
router.get('/buyers', async (req, res) => {
  const { data, error } = await supabase
    .from('users')
    .select('id, name, phone, created_at')
    .eq('role', 'buyer')
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) return res.status(500).json({ error: 'Failed to fetch buyers.' });
  res.json({ buyers: data || [] });
});

module.exports = router;
