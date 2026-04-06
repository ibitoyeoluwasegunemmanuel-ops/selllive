// routes/explore.js — Trending Live algorithm + explore feed
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

// ============================================================
// GET /api/explore/trending
// Trending live streams — scored by viewers + orders + shares
// Decays over time so freshness matters
// ============================================================
router.get('/trending', async (req, res) => {
  // Update trending scores first
  await supabase.rpc('update_trending_scores');

  const { data: streams, error } = await supabase
    .from('streams')
    .select(`
      id, title, thumbnail_url, viewer_count, total_orders,
      share_count, trending_score, started_at,
      seller:users!seller_id(id, name, avatar_url),
      seller_profile:seller_profiles!seller_id(business_name, trust_score, followers_count),
      products:stream_products(id, name, price, image_url, is_active)
    `)
    .eq('status', 'live')
    .order('trending_score', { ascending: false })
    .limit(20);

  if (error) return res.status(500).json({ error: 'Failed to fetch trending.' });
  res.json({ streams: streams || [] });
});

// ============================================================
// GET /api/explore/search?q=ankara
// Search live streams by title or seller name
// ============================================================
router.get('/search', async (req, res) => {
  const { q } = req.query;
  if (!q || q.length < 2) {
    return res.status(400).json({ error: 'Search query must be at least 2 characters.' });
  }

  const { data: streams } = await supabase
    .from('streams')
    .select(`
      id, title, thumbnail_url, viewer_count, status,
      seller:users!seller_id(name, avatar_url),
      seller_profile:seller_profiles!seller_id(business_name)
    `)
    .or(`title.ilike.%${q}%`)
    .in('status', ['live', 'scheduled'])
    .order('viewer_count', { ascending: false })
    .limit(20);

  // Also search sellers
  const { data: sellers } = await supabase
    .from('seller_profiles')
    .select(`
      business_name, trust_score, followers_count,
      user:users!user_id(id, name, avatar_url)
    `)
    .ilike('business_name', `%${q}%`)
    .eq('is_verified', true)
    .limit(10);

  res.json({ streams: streams || [], sellers: sellers || [] });
});

// ============================================================
// GET /api/explore/categories
// Browse by product categories
// ============================================================
router.get('/categories', async (req, res) => {
  const categories = [
    { id: 'fashion', name: 'Fashion & Clothing', icon: '👗', emoji: '👗' },
    { id: 'shoes', name: 'Shoes & Bags', icon: '👟', emoji: '👟' },
    { id: 'electronics', name: 'Electronics', icon: '📱', emoji: '📱' },
    { id: 'beauty', name: 'Beauty & Skincare', icon: '💄', emoji: '💄' },
    { id: 'food', name: 'Food & Drinks', icon: '🍲', emoji: '🍲' },
    { id: 'home', name: 'Home & Kitchen', icon: '🏠', emoji: '🏠' },
    { id: 'jewelry', name: 'Jewelry', icon: '💍', emoji: '💍' },
    { id: 'fabric', name: 'Fabrics & Lace', icon: '🧵', emoji: '🧵' },
  ];
  res.json({ categories });
});

// ============================================================
// POST /api/explore/share/:streamId
// Track WhatsApp share — increments share count
// Returns shareable link
// ============================================================
router.post('/share/:streamId', async (req, res) => {
  const { streamId } = req.params;

  // Increment share count
  await supabase.rpc('increment_share_count', { stream_id: streamId });

  // Also log event for analytics
  await supabase.from('stream_events').insert({
    stream_id: streamId,
    event: 'share',
  });

  const shareUrl = `${process.env.APP_URL || 'https://selllive.vercel.app'}/stream/${streamId}`;
  const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(`🔴 Watch this live sale on SellLive!\n\n${shareUrl}\n\nType BUY to order instantly while watching 🛍️`)}`;

  res.json({
    success: true,
    share_url: shareUrl,
    whatsapp_url: whatsappUrl,
  });
});

module.exports = router;
