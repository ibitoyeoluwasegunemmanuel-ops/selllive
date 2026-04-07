// routes/whatsapp.js — WhatsApp Business API order updates
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');

const WA_TOKEN = process.env.WHATSAPP_TOKEN;
const WA_PHONE_ID = process.env.WHATSAPP_PHONE_ID;

// Send WhatsApp message helper
const sendWhatsApp = async (phone, template, components = []) => {
  if (!WA_TOKEN || !WA_PHONE_ID) return false;
  // Normalize Nigerian numbers
  let normalized = phone.replace(/\D/g, '');
  if (normalized.startsWith('0')) normalized = '234' + normalized.slice(1);
  if (!normalized.startsWith('234')) normalized = '234' + normalized;

  try {
    await axios.post(
      `https://graph.facebook.com/v18.0/${WA_PHONE_ID}/messages`,
      {
        messaging_product: 'whatsapp',
        to: normalized,
        type: 'template',
        template: { name: template, language: { code: 'en' }, components },
      },
      { headers: { Authorization: `Bearer ${WA_TOKEN}`, 'Content-Type': 'application/json' } }
    );
    return true;
  } catch (err) {
    console.error('WhatsApp send error:', err.response?.data || err.message);
    return false;
  }
};

// Send plain text (for when templates aren't set up yet)
const sendWhatsAppText = async (phone, message) => {
  if (!WA_TOKEN || !WA_PHONE_ID) {
    console.log(`[WhatsApp MOCK] To: ${phone} | Msg: ${message.slice(0, 60)}...`);
    return true;
  }
  let normalized = phone.replace(/\D/g, '');
  if (normalized.startsWith('0')) normalized = '234' + normalized.slice(1);
  if (!normalized.startsWith('234')) normalized = '234' + normalized;

  try {
    await axios.post(
      `https://graph.facebook.com/v18.0/${WA_PHONE_ID}/messages`,
      { messaging_product: 'whatsapp', to: normalized, type: 'text', text: { body: message } },
      { headers: { Authorization: `Bearer ${WA_TOKEN}` } }
    );
    return true;
  } catch (err) {
    console.error('WhatsApp text error:', err.response?.data?.error?.message || err.message);
    return false;
  }
};

// Auto-send on order paid (called from webhook)
const notifyOrderPaid = async (orderId) => {
  const { data: order } = await supabase
    .from('orders')
    .select(`
      order_ref, total_amount, delivery_phone,
      buyer:users!buyer_id(name, phone),
      seller:users!seller_id(name, phone),
      product:stream_products!product_id(name)
    `)
    .eq('id', orderId)
    .single();

  if (!order) return;
  const amount = (order.total_amount / 100).toLocaleString();
  const phone = order.delivery_phone || order.buyer?.phone;

  // Message to buyer
  if (phone) {
    await sendWhatsAppText(phone,
      `✅ *SellLive Order Confirmed!*\n\n` +
      `Order: ${order.order_ref}\n` +
      `Item: ${order.product?.name || 'Your order'}\n` +
      `Amount: ₦${amount}\n\n` +
      `Your seller has been notified and will ship soon.\n` +
      `Track your order in the SellLive app 📱`
    );
  }

  // Message to seller
  if (order.seller?.phone) {
    await sendWhatsAppText(order.seller.phone,
      `🛒 *New Order on SellLive!*\n\n` +
      `Order: ${order.order_ref}\n` +
      `Item: ${order.product?.name || 'Your product'}\n` +
      `Payment: ₦${amount} received ✅\n\n` +
      `Please pack and ship within 24 hours.\n` +
      `Open SellLive app to manage orders 📦`
    );
  }
};

const notifyOrderShipped = async (orderId) => {
  const { data: order } = await supabase
    .from('orders')
    .select('order_ref, delivery_phone, buyer:users!buyer_id(name, phone)')
    .eq('id', orderId)
    .single();

  if (!order) return;
  const phone = order.delivery_phone || order.buyer?.phone;
  if (phone) {
    await sendWhatsAppText(phone,
      `📦 *Your SellLive order has been shipped!*\n\n` +
      `Order: ${order.order_ref}\n\n` +
      `Your item is on the way. Expected delivery: 1-3 business days.\n\n` +
      `Questions? Reply to this message or chat the seller in the SellLive app.`
    );
  }
};

// Webhook verification (Meta requires this)
router.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];
  if (mode === 'subscribe' && token === process.env.WHATSAPP_VERIFY_TOKEN) {
    res.status(200).send(challenge);
  } else {
    res.status(403).send('Forbidden');
  }
});

// Incoming messages webhook
router.post('/webhook', express.json(), async (req, res) => {
  res.status(200).json({ status: 'received' });
  // Handle incoming messages if needed
});

module.exports = { router, notifyOrderPaid, notifyOrderShipped };
