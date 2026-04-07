// routes/payments.js — Flutterwave payment integration
// Flutterwave docs: https://developer.flutterwave.com
const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

const FLW_SECRET_KEY = process.env.FLW_SECRET_KEY;
const COMMISSION = Number(process.env.COMMISSION_PERCENT) / 100;  // 0.10

// ============================================================
// POST /api/payments/initiate
// Called when buyer types BUY — creates order + payment link
// ============================================================
router.post('/initiate', authenticate, async (req, res) => {
  const { product_id, stream_id, quantity = 1, delivery_address, delivery_phone } = req.body;

  if (!product_id || !stream_id) {
    return res.status(400).json({ error: 'product_id and stream_id are required.' });
  }

  // Get product details
  const { data: product } = await supabase
    .from('stream_products')
    .select('*, stream:streams!stream_id(seller_id)')
    .eq('id', product_id)
    .eq('is_active', true)
    .single();

  if (!product) return res.status(404).json({ error: 'Product not found or no longer available.' });

  // Check stock
  if (product.stock < quantity) {
    return res.status(400).json({ error: `Only ${product.stock} items left in stock.` });
  }

  // Calculate amounts (all in kobo)
  const totalAmount = product.price * quantity;
  const commission = Math.floor(totalAmount * COMMISSION);
  const sellerPayout = totalAmount - commission;

  // Get buyer details
  const { data: buyer } = await supabase
    .from('users')
    .select('name, phone, email')
    .eq('id', req.user.id)
    .single();

  // Create order record
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
      delivery_phone: delivery_phone || req.user.phone,
      status: 'payment_initiated',
    })
    .select()
    .single();

  if (orderError) return res.status(500).json({ error: 'Failed to create order.' });

  // Create Flutterwave payment link
  const flwTxRef = `SL-${order.id.split('-')[0]}-${Date.now()}`;
  const amountInNaira = totalAmount / 100;  // Flutterwave uses naira, not kobo

  try {
    const flwResponse = await axios.post(
      'https://api.flutterwave.com/v3/payments',
      {
        tx_ref: flwTxRef,
        amount: amountInNaira,
        currency: 'NGN',
        redirect_url: `${process.env.APP_URL}/payment/callback?order_id=${order.id}`,
        meta: {
          order_id: order.id,
          seller_id: product.stream.seller_id,
        },
        customer: {
          email: buyer.email || `${req.user.id}@selllive.ng`,  // Flutterwave requires email
          phonenumber: buyer.phone,
          name: buyer.name,
        },
        customizations: {
          title: 'SellLive Payment',
          description: `${product.name} x${quantity}`,
          logo: 'https://selllive.ng/logo.png',
        },
        payment_options: 'card,ussd,banktransfer,mobilemoney',
      },
      {
        headers: {
          Authorization: `Bearer ${FLW_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    const paymentLink = flwResponse.data.data.link;

    // Update order with Flutterwave reference
    await supabase
      .from('orders')
      .update({ flw_tx_ref: flwTxRef, payment_url: paymentLink })
      .eq('id', order.id);

    // Reduce stock
    await supabase
      .from('stream_products')
      .update({ stock: product.stock - quantity })
      .eq('id', product_id);

    res.json({
      success: true,
      order_id: order.id,
      order_ref: order.order_ref,
      payment_url: paymentLink,
      amount: amountInNaira,
      message: `Payment link created for ₦${amountInNaira.toLocaleString()}`,
    });

  } catch (flwError) {
    console.error('Flutterwave error:', flwError.response?.data || flwError.message);
    // Cancel the order if payment link fails
    await supabase.from('orders').update({ status: 'cancelled' }).eq('id', order.id);
    return res.status(500).json({ error: 'Failed to create payment link. Please try again.' });
  }
});

// ============================================================
// GET /api/payments/verify/:tx_ref
// Verify payment after buyer completes on Flutterwave
// ============================================================
router.get('/verify/:tx_ref', authenticate, async (req, res) => {
  const { tx_ref } = req.params;

  try {
    // Verify with Flutterwave
    const flwResponse = await axios.get(
      `https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=${tx_ref}`,
      {
        headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` },
      }
    );

    const transaction = flwResponse.data.data;

    if (transaction.status !== 'successful') {
      return res.status(400).json({ error: 'Payment was not successful.' });
    }

    // Get order
    const { data: order } = await supabase
      .from('orders')
      .select('*')
      .eq('flw_tx_ref', tx_ref)
      .single();

    if (!order) return res.status(404).json({ error: 'Order not found.' });

    // Check amount matches (fraud prevention)
    const expectedAmount = order.total_amount / 100;  // convert kobo to naira
    if (transaction.amount < expectedAmount) {
      console.error(`⚠️ Amount mismatch! Expected ₦${expectedAmount}, got ₦${transaction.amount}`);
      return res.status(400).json({ error: 'Payment amount mismatch.' });
    }

    // Update order to paid
    await supabase
      .from('orders')
      .update({
        status: 'paid',
        flw_tx_id: String(transaction.id),
        paid_at: new Date().toISOString(),
      })
      .eq('id', order.id);

    // Update seller total earnings
    await supabase.rpc('increment_earnings', {
      seller_id: order.seller_id,
      amount: order.seller_payout,
    });

    // Create commission record
    await supabase.from('commissions').insert({
      order_id: order.id,
      amount: order.commission,
    });

    res.json({
      success: true,
      order_ref: order.order_ref,
      message: 'Payment verified! Your order is confirmed.',
    });

  } catch (err) {
    console.error('Payment verification error:', err.message);
    res.status(500).json({ error: 'Failed to verify payment.' });
  }
});

// ============================================================
// POST /webhook/flutterwave
// Flutterwave sends payment updates here
// This runs even if buyer doesn't return to the app
// ============================================================
router.post('/flutterwave', express.raw({ type: 'application/json' }), async (req, res) => {
  // Verify the webhook is from Flutterwave
  const signature = req.headers['verif-hash'];
  if (signature !== process.env.FLW_WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'Unauthorized webhook.' });
  }

  const event = JSON.parse(req.body);

  if (event.event === 'charge.completed' && event.data.status === 'successful') {
    const txRef = event.data.tx_ref;

    // Find order
    const { data: order } = await supabase
      .from('orders')
      .select('*')
      .eq('flw_tx_ref', txRef)
      .single();

    if (order && order.status === 'payment_initiated') {
      // Mark as paid (same as verify endpoint)
      await supabase.from('orders').update({
        status: 'paid',
        flw_tx_id: String(event.data.id),
        paid_at: new Date().toISOString(),
      }).eq('id', order.id);

      console.log(`✅ Payment confirmed via webhook: ${order.order_ref}`);
    }
  }

  res.json({ received: true });
});

module.exports = router;
// routes/payments.js — Payment callbacks and verification
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { notifyOrderPaid } = require('./whatsapp');

// GET /api/payments/callback — Flutterwave redirects buyer here after payment
// Works for both stream orders and post orders
router.get('/callback', async (req, res) => {
  const { status, tx_ref, transaction_id, order_id, type } = req.query;

  // Redirect to app deep link so Flutter catches it
  if (status !== 'successful') {
    return res.redirect(`selllive://payment/failed?order_id=${order_id || ''}`);
  }

  // Verify the transaction with Flutterwave
  try {
    if (process.env.FLW_SECRET_KEY && transaction_id) {
      const flwRes = await axios.get(
        `https://api.flutterwave.com/v3/transactions/${transaction_id}/verify`,
        { headers: { Authorization: `Bearer ${process.env.FLW_SECRET_KEY}` } }
      );

      if (flwRes.data.data.status === 'successful') {
        const table = type === 'post' ? 'post_orders' : 'orders';
        const COMMISSION = Number(process.env.COMMISSION_PERCENT || 10) / 100;
        const amountKobo = Math.round(flwRes.data.data.amount * 100);
        const sellerPayout = Math.floor(amountKobo * (1 - COMMISSION));

        // Find and update order
        const { data: order } = await supabase.from(table)
          .select('id, seller_id, buyer_id, status')
          .eq('flw_tx_ref', tx_ref).single();

        if (order && order.status !== 'paid') {
          await supabase.from(table).update({ status: 'paid', paid_at: new Date() }).eq('id', order.id);
          await supabase.rpc('increment_earnings', { seller_id: order.seller_id, amount: sellerPayout });

          // WhatsApp notification
          await notifyOrderPaid(order.id).catch(console.error);

          // In-app notifications
          await supabase.from('notifications').insert([
            { user_id: order.seller_id, type: 'payment_received', title: '💰 Payment Received!', body: `₦${(sellerPayout/100).toLocaleString()} added to your wallet`, data: { order_id: order.id } },
            { user_id: order.buyer_id, type: 'new_order', title: '✅ Order Confirmed!', body: `Your order has been paid. Seller will ship soon.`, data: { order_id: order.id } },
          ]);
        }
      }
    }
  } catch (err) {
    console.error('Payment verify error:', err.message);
  }

  // Redirect to app — Flutter handles selllive:// deep link
  res.redirect(`selllive://payment/success?order_id=${order_id || ''}&tx_ref=${tx_ref || ''}`);
});

// POST /api/payments/verify — manual verification from Flutter
router.post('/verify', async (req, res) => {
  const { transaction_id, tx_ref } = req.body;
  if (!transaction_id && !tx_ref) return res.status(400).json({ error: 'transaction_id or tx_ref required.' });

  try {
    if (process.env.FLW_SECRET_KEY) {
      const flwRes = await axios.get(
        `https://api.flutterwave.com/v3/transactions/${transaction_id}/verify`,
        { headers: { Authorization: `Bearer ${process.env.FLW_SECRET_KEY}` } }
      );
      return res.json({ verified: flwRes.data.data.status === 'successful', data: flwRes.data.data });
    }
    res.json({ verified: true, mock: true });
  } catch (err) {
    res.status(500).json({ error: 'Verification failed.' });
  }
});

module.exports = router;
