// routes/notifications_route.js — Notification centre
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

router.get('/', authenticate, async (req, res) => {
  const { data, error } = await supabase.from('notifications')
    .select('*').eq('user_id', req.user.id)
    .order('created_at', { ascending: false }).limit(30);
  if (error) return res.status(500).json({ error: 'Failed.' });
  const unread = (data || []).filter(n => !n.is_read).length;
  res.json({ notifications: data || [], unread_count: unread });
});

router.patch('/read-all', authenticate, async (req, res) => {
  await supabase.from('notifications').update({ is_read: true })
    .eq('user_id', req.user.id).eq('is_read', false);
  res.json({ success: true });
});

module.exports = router;
