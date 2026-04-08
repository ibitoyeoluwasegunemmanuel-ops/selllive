// routes/chat.js — Direct messaging + Voice/Video calls
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// ============================================================
// GET /api/chat/conversations
// Get all conversations for the current user
// ============================================================
router.get('/conversations', authenticate, async (req, res) => {
  const userId = req.user.id;
  const isSeller = req.user.role === 'seller';

  const { data: conversations, error } = await supabase
    .from('conversations')
    .select(`
      id, last_message, last_message_at, buyer_unread, seller_unread,
      buyer:users!buyer_id(id, name, avatar_url),
      seller:users!seller_id(id, name, avatar_url)
    `)
    .or(`buyer_id.eq.${userId},seller_id.eq.${userId}`)
    .order('last_message_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Failed to fetch conversations.' });

  // Add unread count relevant to current user
  const enriched = (conversations || []).map(c => ({
    ...c,
    unread_count: isSeller ? c.seller_unread : c.buyer_unread,
    other_user: isSeller ? c.buyer : (c.seller_profile ? { ...c.seller, name: c.seller_profile.business_name } : c.seller),
  }));

  res.json({ conversations: enriched });
});

// ============================================================
// GET /api/chat/conversations/:id/messages
// Get messages in a conversation
// ============================================================
router.get('/conversations/:id/messages', authenticate, async (req, res) => {
  const { data: messages, error } = await supabase
    .from('messages')
    .select(`
      id, content, message_type, product_data, order_data, is_read, created_at,
      sender:users!sender_id(id, name, avatar_url)
    `)
    .eq('conversation_id', req.params.id)
    .order('created_at', { ascending: true })
    .limit(100);

  if (error) return res.status(500).json({ error: 'Failed to fetch messages.' });

  // Mark as read
  const userId = req.user.id;
  await supabase.from('messages').update({ is_read: true })
    .eq('conversation_id', req.params.id)
    .neq('sender_id', userId)
    .eq('is_read', false);

  // Reset unread count
  const conv = await supabase.from('conversations').select('buyer_id').eq('id', req.params.id).single();
  if (conv.data?.buyer_id === userId) {
    await supabase.from('conversations').update({ buyer_unread: 0 }).eq('id', req.params.id);
  } else {
    await supabase.from('conversations').update({ seller_unread: 0 }).eq('id', req.params.id);
  }

  res.json({ messages: messages || [] });
});

// ============================================================
// POST /api/chat/conversations
// Start or get a conversation between buyer and seller
// ============================================================
router.post('/conversations', authenticate, async (req, res) => {
  const { seller_id } = req.body;
  const buyerId = req.user.id;

  if (!seller_id) return res.status(400).json({ error: 'seller_id required.' });
  if (seller_id === buyerId) return res.status(400).json({ error: 'Cannot chat with yourself.' });

  // Upsert conversation
  const { data: conv, error } = await supabase
    .from('conversations')
    .upsert({ buyer_id: buyerId, seller_id }, { onConflict: 'buyer_id,seller_id' })
    .select()
    .single();

  if (error) return res.status(500).json({ error: 'Failed to create conversation.' });
  res.json({ conversation: conv });
});

// ============================================================
// POST /api/chat/conversations/:id/messages
// Send a message
// ============================================================
router.post('/conversations/:id/messages', authenticate, async (req, res) => {
  const { content, message_type = 'text', product_data, order_data } = req.body;
  if (!content?.trim() && !product_data) return res.status(400).json({ error: 'Message content required.' });

  // Verify user is part of this conversation
  const { data: conv } = await supabase
    .from('conversations')
    .select('buyer_id, seller_id')
    .eq('id', req.params.id)
    .single();

  if (!conv || (conv.buyer_id !== req.user.id && conv.seller_id !== req.user.id)) {
    return res.status(403).json({ error: 'Not part of this conversation.' });
  }

  const { data: message, error } = await supabase
    .from('messages')
    .insert({
      conversation_id: req.params.id,
      sender_id: req.user.id,
      content: content?.trim(),
      message_type,
      product_data: product_data || null,
      order_data: order_data || null,
    })
    .select(`id, content, message_type, product_data, order_data, created_at, sender:users!sender_id(id, name, avatar_url)`)
    .single();

  if (error) return res.status(500).json({ error: 'Failed to send message.' });
  res.status(201).json({ message });
});

// ============================================================
// POST /api/chat/conversations/:id/share-product
// Send a product card in chat
// ============================================================
router.post('/conversations/:id/share-product', authenticate, async (req, res) => {
  const { name, price, image_url, product_id, post_id } = req.body;
  if (!name || !price) return res.status(400).json({ error: 'Product name and price required.' });

  const { data: message, error } = await supabase
    .from('messages')
    .insert({
      conversation_id: req.params.id,
      sender_id: req.user.id,
      content: `Check out this product: ${name}`,
      message_type: 'product_card',
      product_data: { name, price, image_url, product_id, post_id },
    })
    .select(`id, content, message_type, product_data, created_at, sender:users!sender_id(id, name, avatar_url)`)
    .single();

  if (error) return res.status(500).json({ error: 'Failed to share product.' });
  res.status(201).json({ message });
});

// ============================================================
// POST /api/chat/calls/initiate
// Start a voice or video call
// ============================================================
router.post('/calls/initiate', authenticate, async (req, res) => {
  const { conversation_id, call_type = 'voice' } = req.body;
  if (!conversation_id) return res.status(400).json({ error: 'conversation_id required.' });

  // Get conversation to find receiver
  const { data: conv } = await supabase
    .from('conversations')
    .select('buyer_id, seller_id')
    .eq('id', conversation_id)
    .single();

  if (!conv) return res.status(404).json({ error: 'Conversation not found.' });

  const receiverId = conv.buyer_id === req.user.id ? conv.seller_id : conv.buyer_id;

  // Create Daily.co room for the call
  let dailyRoomUrl = null;
  let dailyRoomName = null;

  if (process.env.DAILY_API_KEY) {
    try {
      const callId = `call-${Date.now()}`;
      const response = await axios.post(
        'https://api.daily.co/v1/rooms',
        {
          name: callId,
          properties: {
            max_participants: 2,
            exp: Math.floor(Date.now() / 1000) + 3600, // 1 hour
            enable_chat: false,
            enable_screenshare: false,
            start_video_off: call_type === 'voice',
            start_audio_off: false,
          },
        },
        { headers: { Authorization: `Bearer ${process.env.DAILY_API_KEY}` } }
      );
      dailyRoomUrl = response.data.url;
      dailyRoomName = response.data.name;
    } catch (err) {
      console.error('Daily.co room creation failed:', err.message);
    }
  }

  // Create call record
  const { data: call, error } = await supabase
    .from('calls')
    .insert({
      conversation_id,
      caller_id: req.user.id,
      receiver_id: receiverId,
      call_type,
      status: 'ringing',
      daily_room_url: dailyRoomUrl,
      daily_room_name: dailyRoomName,
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: 'Failed to initiate call.' });

  // Send call_started message in conversation
  await supabase.from('messages').insert({
    conversation_id,
    sender_id: req.user.id,
    content: `📞 ${call_type === 'video' ? 'Video' : 'Voice'} call started`,
    message_type: 'call_started',
  });

  res.json({
    call_id: call.id,
    call_type,
    daily_room_url: dailyRoomUrl,
    receiver_id: receiverId,
  });
});

// ============================================================
// PATCH /api/chat/calls/:id
// Update call status (accept, reject, end)
// ============================================================
router.patch('/calls/:id', authenticate, async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['active', 'ended', 'missed', 'rejected'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: 'Invalid status.' });
  }

  const updates = { status };
  if (status === 'active') updates.started_at = new Date().toISOString();
  if (status === 'ended' || status === 'rejected' || status === 'missed') {
    updates.ended_at = new Date().toISOString();
    // Calculate duration
    const { data: call } = await supabase.from('calls').select('started_at').eq('id', req.params.id).single();
    if (call?.started_at) {
      updates.duration_secs = Math.floor((Date.now() - new Date(call.started_at)) / 1000);
    }

    // Send call_ended message
    const { data: callData } = await supabase.from('calls').select('conversation_id, call_type, duration_secs').eq('id', req.params.id).single();
    if (callData) {
      const durationStr = updates.duration_secs > 0
        ? ` (${Math.floor(updates.duration_secs / 60)}m ${updates.duration_secs % 60}s)`
        : '';
      await supabase.from('messages').insert({
        conversation_id: callData.conversation_id,
        sender_id: req.user.id,
        content: `${status === 'rejected' ? '❌ Call rejected' : status === 'missed' ? '📵 Missed call' : `✅ Call ended${durationStr}`}`,
        message_type: 'call_ended',
      });
    }
  }

  await supabase.from('calls').update(updates).eq('id', req.params.id);
  res.json({ success: true, status });
});

module.exports = router;
