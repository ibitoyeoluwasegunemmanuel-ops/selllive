// routes/notifications.js — Push notifications via Firebase
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// ============================================================
// Send push notification to all followers when seller goes live
// Called automatically when POST /api/streams is hit
// ============================================================
const notifyFollowers = async (sellerId, streamTitle, streamId) => {
  if (!process.env.FIREBASE_SERVER_KEY) return;

  try {
    // Get all followers with FCM tokens
    const { data: followers } = await supabase
      .from('follows')
      .select('follower:users!follower_id(fcm_token, name)')
      .eq('seller_id', sellerId);

    const tokens = (followers || [])
      .map(f => f.follower?.fcm_token)
      .filter(Boolean);

    if (!tokens.length) return;

    // Get seller name
    const { data: seller } = await supabase
      .from('seller_profiles')
      .select('business_name')
      .eq('user_id', sellerId)
      .single();

    const sellerName = seller?.business_name || 'A seller you follow';

    // Send FCM notification
    await axios.post(
      'https://fcm.googleapis.com/fcm/send',
      {
        registration_ids: tokens,
        notification: {
          title: `🔴 ${sellerName} is LIVE!`,
          body: streamTitle,
          sound: 'default',
          badge: '1',
        },
        data: {
          stream_id: streamId,
          seller_id: sellerId,
          type: 'live_started',
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'selllive_live',
            color: '#FF5722',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      },
      {
        headers: {
          Authorization: `key=${process.env.FIREBASE_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    console.log(`✅ Notified ${tokens.length} followers that ${sellerName} went live`);
  } catch (err) {
    console.error('Push notification failed:', err.message);
  }
};

// ============================================================
// POST /api/notifications/update-token
// Called by Flutter app when FCM token changes
// ============================================================
router.post('/update-token', authenticate, async (req, res) => {
  const { fcm_token } = req.body;
  if (!fcm_token) return res.status(400).json({ error: 'fcm_token required.' });

  await supabase
    .from('users')
    .update({ fcm_token })
    .eq('id', req.user.id);

  res.json({ success: true });
});

module.exports = { router, notifyFollowers };
