// routes/loyalty.js — Buyer loyalty points system
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// Points: 1 point per ₦100 spent. 100 points = ₦500 discount
const POINTS_PER_NAIRA = 0.01;  // 1 point per ₦100
const POINTS_TO_NAIRA = 5;       // 100 points = ₦500

router.get('/', authenticate, async (req, res) => {
  const { data: user } = await supabase.from('users').select('loyalty_points').eq('id', req.user.id).single();
  const points = user?.loyalty_points || 0;
  res.json({
    points,
    naira_value: Math.floor(points / 100) * POINTS_TO_NAIRA,
    next_reward_at: Math.ceil(points / 100) * 100,
    points_to_next: Math.max(0, Math.ceil(points / 100) * 100 - points),
    rewards_available: Math.floor(points / 100),
  });
});

router.post('/redeem', authenticate, async (req, res) => {
  const { points_to_redeem } = req.body;
  if (!points_to_redeem || points_to_redeem < 100) return res.status(400).json({ error: 'Minimum 100 points to redeem.' });
  if (points_to_redeem % 100 !== 0) return res.status(400).json({ error: 'Redeem in multiples of 100 points.' });

  const { data: user } = await supabase.from('users').select('loyalty_points').eq('id', req.user.id).single();
  if ((user?.loyalty_points || 0) < points_to_redeem) return res.status(400).json({ error: 'Not enough points.' });

  const discount = Math.floor(points_to_redeem / 100) * POINTS_TO_NAIRA;
  await supabase.from('users').update({ loyalty_points: (user.loyalty_points - points_to_redeem) }).eq('id', req.user.id);

  res.json({ success: true, discount_naira: discount, message: `₦${discount} discount applied to your next order!` });
});

module.exports = router;
