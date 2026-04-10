// routes/payments.js — Real Flutterwave payment initiation & verification
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

const FLW_SECRET = process.env.FLW_SECRET_KEY;
const BASE_URL = process.env.APP_URL || 'https://selllive.vercel.app';

// POST /api/payments/initiate — create Flutterwave payment link for an order
router.post('/initiate', authenticate, async (req, res) => {
  const { order_id, items, delivery_address, delivery_phone, total_amount } = req.body;

  // Get user info
  const { data: user } = await supabase.from('users').select('name, phone').eq('id', req.user.id).single();

  // Generate unique tx_ref
  const txRef = `SL-${Date.now()}-${Math.random().toString(36).substr(2,6).toUpperCase()}`;

  try {
    const payload = {
      tx_ref: txRef,
      amount: total_amount / 100, // convert kobo to naira
      currency: 'NGN',
      redirect_url: `${BASE_URL}/payment/verify?tx_ref=${txRef}&order_id=${order_id || ''}`,
      customer: {
        email: `${(user?.phone||'').replace('+','').replace(/\s/g,'')}@selllive.ng`,
        phonenumber: user?.phone || delivery_phone,
        name: user?.name || 'SellLive Customer',
      },
      customizations: {
        title: 'SellLive',
        description: 'Order payment',
        logo: `${BASE_URL}/favicon.ico`,
      },
      meta: { order_id, buyer_id: req.user.id },
    };

    if (FLW_SECRET && FLW_SECRET.startsWith('FLWSECK')) {
      // Live Flutterwave call
      const resp = await axios.post('https://api.flutterwave.com/v3/payments', payload, {
        headers: { Authorization: `Bearer ${FLW_SECRET}`, 'Content-Type': 'application/json' },
        timeout: 15000,
      });
      if (resp.data?.status === 'success') {
        const paymentLink = resp.data.data.link;
        // Save tx_ref to order if we have one
        if (order_id) {
          await supabase.from('orders').update({ flw_tx_ref: txRef, payment_status: 'pending', flw_payment_link: paymentLink }).eq('id', order_id);
        }
        return res.json({ success: true, payment_link: paymentLink, tx_ref: txRef });
      }
      return res.status(500).json({ error: 'Flutterwave did not return a payment link' });
    } else {
      // Dev mode — return mock payment link
      console.log('DEV: Flutterwave tx_ref:', txRef, 'amount:', payload.amount);
      return res.json({
        success: true,
        payment_link: `https://checkout.flutterwave.com/v3/hosted/pay/demo?tx_ref=${txRef}`,
        tx_ref: txRef,
        dev_mode: true,
        message: `DEV MODE: tx_ref=${txRef}, amount=₦${payload.amount}`,
      });
    }
  } catch (err) {
    console.error('Flutterwave error:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Payment initiation failed. Try again.' });
  }
});

// POST /api/payments/verify — verify payment after redirect
router.post('/verify', authenticate, async (req, res) => {
  const { tx_ref, transaction_id } = req.body;
  if (!tx_ref && !transaction_id) return res.status(400).json({ error: 'tx_ref or transaction_id required' });

  try {
    if (FLW_SECRET && FLW_SECRET.startsWith('FLWSECK')) {
      const resp = await axios.get(`https://api.flutterwave.com/v3/transactions/${transaction_id}/verify`, {
        headers: { Authorization: `Bearer ${FLW_SECRET}` },
      });
      const txData = resp.data?.data;
      if (!txData) return res.status(400).json({ error: 'Transaction not found' });

      if (txData.status === 'successful' && txData.currency === 'NGN') {
        // Mark order as paid
        if (txData.meta?.order_id) {
          await supabase.from('orders').update({ status: 'paid', payment_status: 'paid', flw_tx_id: String(transaction_id), paid_at: new Date().toISOString() }).eq('id', txData.meta.order_id);
        }
        return res.json({ success: true, status: 'paid', amount: txData.amount, tx_ref: txData.tx_ref });
      }
      return res.json({ success: false, status: txData.status });
    } else {
      // Dev mode — mark as paid automatically
      return res.json({ success: true, status: 'paid', dev_mode: true });
    }
  } catch (err) {
    console.error('Verify error:', err.response?.data || err.message);
    return res.status(500).json({ error: 'Verification failed' });
  }
});

// POST /api/payments/checkout — full cart checkout (create orders + initiate payment)
router.post('/checkout', authenticate, async (req, res) => {
  const { items, delivery_address, delivery_phone } = req.body;
  // items = [{ product_id, quantity, price }]
  if (!items?.length) return res.status(400).json({ error: 'No items in order' });
  if (!delivery_address) return res.status(400).json({ error: 'Delivery address required' });

  const totalAmount = items.reduce((s, i) => s + (i.price * i.quantity), 0);
  const commission = Math.round(totalAmount * 0.10);

  // Create orders for each item
  const orderInserts = items.map(item => ({
    buyer_id: req.user.id,
    seller_id: item.seller_id || null,
    product_id: item.product_id,
    quantity: item.quantity,
    unit_price: item.price,
    total_amount: item.price * item.quantity,
    commission: Math.round(item.price * item.quantity * 0.10),
    seller_payout: Math.round(item.price * item.quantity * 0.90),
    delivery_address,
    delivery_phone: delivery_phone || '',
    status: 'pending',
    payment_status: 'pending',
    order_ref: `SL-${Date.now()}-${Math.random().toString(36).substr(2,4).toUpperCase()}`,
  }));

  const { data: orders, error } = await supabase.from('orders').insert(orderInserts).select();
  if (error) return res.status(500).json({ error: 'Failed to create orders' });

  // Clear cart after creating orders
  await supabase.from('cart_items').delete().eq('user_id', req.user.id);

  // Initiate payment for total
  const txRef = `SL-${Date.now()}-${Math.random().toString(36).substr(2,6).toUpperCase()}`;
  const { data: user } = await supabase.from('users').select('name, phone').eq('id', req.user.id).single();
  const orderIds = orders.map(o => o.id).join(',');

  try {
    const payload = {
      tx_ref: txRef,
      amount: totalAmount / 100,
      currency: 'NGN',
      redirect_url: `${BASE_URL}/payment/verify?tx_ref=${txRef}&orders=${orderIds}`,
      customer: {
        email: `${(user?.phone||'user').replace(/\D/g,'')}@selllive.ng`,
        phonenumber: user?.phone || delivery_phone,
        name: user?.name || 'Customer',
      },
      customizations: { title: 'SellLive', description: `${items.length} items` },
    };

    if (FLW_SECRET && FLW_SECRET.startsWith('FLWSECK')) {
      const resp = await axios.post('https://api.flutterwave.com/v3/payments', payload, {
        headers: { Authorization: `Bearer ${FLW_SECRET}` }, timeout: 15000,
      });
      if (resp.data?.status === 'success') {
        return res.json({ success: true, payment_link: resp.data.data.link, tx_ref: txRef, orders });
      }
    }
    // Dev fallback
    return res.json({ success: true, payment_link: `https://checkout.flutterwave.com/v3/hosted/pay/demo?tx_ref=${txRef}`, tx_ref: txRef, orders, dev_mode: true });
  } catch (err) {
    return res.json({ success: true, payment_link: null, tx_ref: txRef, orders, dev_mode: true, error: err.message });
  }
});

// Flutterwave webhook handler
router.post('/webhook', async (req, res) => {
  const hash = req.headers['verif-hash'];
  if (hash !== process.env.FLW_WEBHOOK_SECRET) return res.status(401).json({ error: 'Unauthorized' });
  const { event, data } = req.body;
  if (event === 'charge.completed' && data.status === 'successful') {
    const orderIds = data.meta?.orders?.split(',') || [];
    if (orderIds.length) {
      await supabase.from('orders').update({ status: 'paid', payment_status: 'paid', flw_tx_id: String(data.id), paid_at: new Date().toISOString() }).in('id', orderIds);
    }
  }
  res.json({ received: true });
});

// GET /api/payments/history — user payment history
router.get('/history', authenticate, async (req, res) => {
  const { data } = await supabase.from('orders').select('id, order_ref, total_amount, status, payment_status, created_at').eq('buyer_id', req.user.id).order('created_at', { ascending: false }).limit(20);
  res.json({ payments: data || [] });
});

module.exports = router;
