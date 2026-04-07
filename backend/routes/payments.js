// routes/payments.js — Flutterwave payment integration
const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

const FLW_SECRET_KEY = process.env.FLW_SECRET_KEY;
const COMMISSION = Number(process.env.COMMISSION_PERCENT || 10) / 100;

// ============================================================
// POST /api/payments/initiate
// Called when buyer types BUY — creates order + payment link
// ============================================================
router.post('/initiate', authenticate, async (req, res) => {
  const { product_id, stream_id, quantity = 1, delivery_address, delivery_phone } = req.body;

  if (!product_id || !stream_id) {
    return res.status(400).json({ error: 'product_id and stream_id are required.' });
  }

  const { data: product } = await supabase
    .from('stream_products')
    .select('*, stream:streams!stream_id(seller_id)')
    .eq('id', product_id)
    .eq('is_active', true)
    .single();

  if (!product) return res.status(404).json({ error: 'Product not found or no longer available.' });

  const { data: buyer } = await supabase
    .from('users').select('name, phone, email').eq('id', req.user.id).single();

  const totalAmount   = product.price * quantity;
  const commission    = Math.floor(totalAmount * COMMISSION);
  const sellerPayout  = totalAmount - commission;

  const { data: order, error: orderError } = await supabase
    .from('orders')
    .insert({
      stream_id,
      product_id,
      buyer_id: req.user.id,
      seller_id: product.stream.seller_id,
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

  const flwTxRef = `SL-${order.id.split('-')[0]}-${Date.now()}`;
  const amountNaira = totalAmount / 100;

  try {
    if (FLW_SECRET_KEY) {
      const flwResponse = await axios.post(
        'https://api.flutterwave.com/v3/payments',
        {
          tx_ref: flwTxRef,
          amount: amountNaira,
          currency: 'NGN',
          redirect_url: `${process.env.APP_URL || 'https://selllive.vercel.app'}/api/payments/callback?order_id=${order.id}&type=stream`,
          meta: { order_id: order.id, type: 'stream_order' },
          customer: {
            email: buyer?.email || `${req.user.id}@selllive.ng`,
            phonenumber: buyer?.phone,
            name: buyer?.name,
          },
          customizations: {
            title: 'SellLive',
            description: `${product.name} x${quantity}`,
          },
        },
        { headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` } }
      );

      const paymentUrl = flwResponse.data.data.link;
      await supabase.from('orders').update({ flw_tx_ref: flwTxRef, payment_url: paymentUrl }).eq('id', order.id);

      return res.json({
        success: true,
        order_id: order.id,
        order_ref: order.order_ref,
        payment_url: paymentUrl,
        amount_naira: amountNaira,
      });
    }

    // Dev mode — return mock payment URL
    res.json({
      success: true,
      order_id: order.id,
      order_ref: order.order_ref,
      payment_url: null,
      amount_naira: amountNaira,
      dev_mode: true,
      message: 'Add FLW_SECRET_KEY to enable real payments.',
    });
  } catch (err) {
    console.error('Flutterwave error:', err.response?.data || err.message);
    res.json({ success: true, order_id: order.id, order_ref: order.order_ref, payment_url: null });
  }
});

// ============================================================
// GET /api/payments/callback — Flutterwave redirect after payment
// ============================================================
router.get('/callback', async (req, res) => {
  const { status, tx_ref, transaction_id, order_id, type } = req.query;

  if (status !== 'successful') {
    return res.redirect(`selllive://payment/failed?order_id=${order_id || ''}`);
  }

  try {
    if (FLW_SECRET_KEY && transaction_id) {
      const flwRes = await axios.get(
        `https://api.flutterwave.com/v3/transactions/${transaction_id}/verify`,
        { headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` } }
      );

      if (flwRes.data.data.status === 'successful') {
        const table       = type === 'post' ? 'post_orders' : 'orders';
        const amountKobo  = Math.round(flwRes.data.data.amount * 100);
        const sellerPayout = Math.floor(amountKobo * (1 - COMMISSION));

        const { data: order } = await supabase.from(table)
          .select('id, seller_id, buyer_id, status').eq('flw_tx_ref', tx_ref).single();

        if (order && order.status !== 'paid') {
          await supabase.from(table).update({ status: 'paid', paid_at: new Date() }).eq('id', order.id);
          await supabase.rpc('increment_earnings', { seller_id: order.seller_id, amount: sellerPayout });
          await supabase.from('notifications').insert([
            { user_id: order.seller_id, type: 'payment_received', title: '💰 Payment Received!', body: `₦${(sellerPayout/100).toLocaleString()} added to your wallet`, data: { order_id: order.id } },
            { user_id: order.buyer_id, type: 'new_order', title: '✅ Order Confirmed!', body: 'Your order has been paid. Seller will ship soon.', data: { order_id: order.id } },
          ]);
        }
      }
    }
  } catch (err) {
    console.error('Payment verify error:', err.message);
  }

  res.redirect(`selllive://payment/success?order_id=${order_id || ''}&tx_ref=${tx_ref || ''}`);
});

// ============================================================
// POST /api/payments/verify — manual verify from Flutter
// ============================================================
router.post('/verify', async (req, res) => {
  const { transaction_id, tx_ref } = req.body;
  if (!transaction_id && !tx_ref) return res.status(400).json({ error: 'transaction_id required.' });

  try {
    if (FLW_SECRET_KEY && transaction_id) {
      const flwRes = await axios.get(
        `https://api.flutterwave.com/v3/transactions/${transaction_id}/verify`,
        { headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` } }
      );
      return res.json({ verified: flwRes.data.data.status === 'successful', data: flwRes.data.data });
    }
    res.json({ verified: true, mock: true });
  } catch (err) {
    res.status(500).json({ error: 'Verification failed.' });
  }
});

// ============================================================
// POST /webhook/flutterwave — server-side webhook (backup)
// ============================================================
router.post('/webhook', express.raw({ type: '*/*' }), async (req, res) => {
  const signature = req.headers['verif-hash'];
  const expectedHash = process.env.FLW_WEBHOOK_SECRET;

  if (expectedHash && signature !== expectedHash) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const event = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  if (event.event !== 'charge.completed' || event.data?.status !== 'successful') {
    return res.json({ received: true });
  }

  const { tx_ref, amount } = event.data;
  const { data: order } = await supabase.from('orders').select('*').eq('flw_tx_ref', tx_ref).single();

  if (order && order.status !== 'paid') {
    const sellerPayout = Math.floor(amount * 100 * (1 - COMMISSION));
    await supabase.from('orders').update({ status: 'paid', paid_at: new Date() }).eq('id', order.id);
    await supabase.rpc('increment_earnings', { seller_id: order.seller_id, amount: sellerPayout });
    await supabase.from('notifications').insert([
      { user_id: order.seller_id, type: 'payment_received', title: '💰 Payment Received!', body: `₦${(sellerPayout/100).toLocaleString()} added to your wallet`, data: { order_id: order.id } },
      { user_id: order.buyer_id, type: 'new_order', title: '✅ Order Confirmed!', body: 'Your order has been paid.', data: { order_id: order.id } },
    ]);
  }

  res.json({ received: true });
});

module.exports = router;
