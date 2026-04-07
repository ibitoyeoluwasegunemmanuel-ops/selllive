// routes/webhook.js — Flutterwave payment webhook
const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const supabase = require('../config/supabase');

const COMMISSION = Number(process.env.COMMISSION_PERCENT || 10) / 100;

router.post('/flutterwave', express.raw({ type: 'application/json' }), async (req, res) => {
  // Verify webhook signature
  const hash = crypto.createHmac('sha256', process.env.FLW_SECRET_HASH || 'selllive-webhook')
    .update(JSON.stringify(req.body)).digest('hex');
  if (req.headers['verif-hash'] !== hash && process.env.NODE_ENV === 'production') {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const event = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;

  if (event.event !== 'charge.completed' || event.data?.status !== 'successful') {
    return res.json({ received: true });
  }

  const { tx_ref, amount, currency } = event.data;
  if (currency !== 'NGN') return res.json({ received: true });

  // Find order by tx_ref
  let order = null;
  let orderTable = 'orders';

  const { data: streamOrder } = await supabase.from('orders').select('*').eq('flw_tx_ref', tx_ref).single();
  if (streamOrder) { order = streamOrder; orderTable = 'orders'; }

  if (!order) {
    const { data: postOrder } = await supabase.from('post_orders').select('*').eq('flw_tx_ref', tx_ref).single();
    if (postOrder) { order = postOrder; orderTable = 'post_orders'; }
  }

  if (!order || order.status === 'paid') return res.json({ received: true });

  // Mark order as paid
  await supabase.from(orderTable).update({
    status: 'paid',
    paid_at: new Date().toISOString(),
  }).eq('id', order.id);

  // Credit seller wallet
  const sellerPayout = order.seller_payout || Math.floor(amount * 100 * (1 - COMMISSION));
  await supabase.rpc('increment_earnings', { seller_id: order.seller_id, amount: sellerPayout });

  // Send notifications
  await supabase.from('notifications').insert([
    {
      user_id: order.seller_id,
      type: 'payment_received',
      title: '💰 Payment Received!',
      body: `₦${(sellerPayout / 100).toLocaleString()} has been added to your wallet`,
      data: { order_id: order.id, amount: sellerPayout },
    },
    {
      user_id: order.buyer_id,
      type: 'new_order',
      title: '✅ Order Confirmed!',
      body: `Your order ${order.order_ref} has been paid. Seller will ship soon.`,
      data: { order_id: order.id },
    },
  ]);

  // Auto-send order update in chat
  const { data: conv } = await supabase.from('conversations')
    .select('id').eq('buyer_id', order.buyer_id).eq('seller_id', order.seller_id).single();
  if (conv) {
    await supabase.from('messages').insert({
      conversation_id: conv.id,
      sender_id: order.seller_id,
      content: `✅ Order ${order.order_ref} confirmed — ₦${(amount).toLocaleString()} received`,
      message_type: 'order_update',
      order_data: { order_ref: order.order_ref, status: 'paid', amount },
    });
  }

  res.json({ received: true });
});

module.exports = router;
