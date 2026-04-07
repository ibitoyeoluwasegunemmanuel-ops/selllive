// routes/logistics.js — GIG Logistics + Kwik Delivery integration
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { authenticate, sellerOnly } = require('../middleware/auth');

// GIG Logistics API
const bookGIGPickup = async ({ orderId, sellerAddress, buyerAddress, itemDesc, itemWeight = 0.5 }) => {
  if (!process.env.GIG_API_KEY) {
    return { success: false, provider: 'GIG', mock: true, tracking: `GIG-MOCK-${Date.now()}` };
  }
  try {
    const res = await axios.post('https://api.gigl-go.com/api/v1/shipment/create', {
      ReceiverAddress: buyerAddress.full_address,
      ReceiverName: buyerAddress.name,
      ReceiverPhoneNumber: buyerAddress.phone,
      SenderAddress: sellerAddress,
      Description: itemDesc,
      Weight: itemWeight,
      DeliveryType: 'Normal',
    }, { headers: { Authorization: `Bearer ${process.env.GIG_API_KEY}` } });
    return { success: true, provider: 'GIG', tracking: res.data.Waybill, data: res.data };
  } catch (err) {
    return { success: false, provider: 'GIG', error: err.message };
  }
};

// Kwik Delivery API
const bookKwikPickup = async ({ orderId, pickup, dropoff, itemDesc }) => {
  if (!process.env.KWIK_API_KEY) {
    return { success: false, provider: 'Kwik', mock: true, tracking: `KWIK-MOCK-${Date.now()}` };
  }
  try {
    const res = await axios.post('https://api.kwik.delivery/api/v1/orders', {
      pickup_address: pickup.address,
      pickup_phone: pickup.phone,
      delivery_address: dropoff.address,
      delivery_phone: dropoff.phone,
      item_description: itemDesc,
    }, { headers: { 'x-api-key': process.env.KWIK_API_KEY } });
    return { success: true, provider: 'Kwik', tracking: res.data.tracking_id, data: res.data };
  } catch (err) {
    return { success: false, provider: 'Kwik', error: err.message };
  }
};

// POST /api/logistics/book — auto-book pickup after payment
router.post('/book', authenticate, sellerOnly, async (req, res) => {
  const { order_id, provider = 'gig' } = req.body;
  if (!order_id) return res.status(400).json({ error: 'order_id required.' });

  const { data: order } = await supabase.from('orders').select(`
    id, order_ref, delivery_address, delivery_phone, total_amount, status,
    seller_id, buyer:users!buyer_id(name, phone),
    product:stream_products!product_id(name, weight_kg)
  `).eq('id', order_id).single();

  if (!order) return res.status(404).json({ error: 'Order not found.' });
  if (order.seller_id !== req.user.id) return res.status(403).json({ error: 'Not your order.' });
  if (order.status !== 'paid') return res.status(400).json({ error: 'Order must be paid first.' });

  const { data: sellerProfile } = await supabase.from('seller_profiles')
    .select('pickup_address, pickup_phone').eq('user_id', req.user.id).single();

  let result;
  if (provider === 'kwik') {
    result = await bookKwikPickup({
      orderId: order.id,
      pickup: { address: sellerProfile?.pickup_address || 'Lagos', phone: sellerProfile?.pickup_phone },
      dropoff: { address: order.delivery_address, phone: order.delivery_phone || order.buyer?.phone },
      itemDesc: order.product?.name || 'SellLive order',
    });
  } else {
    result = await bookGIGPickup({
      orderId: order.id,
      sellerAddress: sellerProfile?.pickup_address || 'Lagos',
      buyerAddress: { full_address: order.delivery_address, name: order.buyer?.name, phone: order.delivery_phone || order.buyer?.phone },
      itemDesc: order.product?.name || 'SellLive order',
      itemWeight: order.product?.weight_kg || 0.5,
    });
  }

  // Update order with tracking
  if (result.success || result.mock) {
    await supabase.from('orders').update({
      status: 'processing',
      tracking_number: result.tracking,
      logistics_provider: result.provider,
    }).eq('id', order.id);
  }

  res.json({ ...result, order_ref: order.order_ref });
});

// GET /api/logistics/track/:trackingNumber
router.get('/track/:tracking', async (req, res) => {
  const { tracking } = req.params;
  // Return mock tracking for now — integrate with real GIG API when key available
  res.json({
    tracking_number: tracking,
    status: 'In Transit',
    events: [
      { time: new Date().toISOString(), location: 'Lagos Hub', status: 'Package received at facility' },
      { time: new Date(Date.now() - 3600000).toISOString(), location: 'Pickup', status: 'Picked up from seller' },
    ],
    estimated_delivery: new Date(Date.now() + 2 * 24 * 3600000).toLocaleDateString(),
  });
});

module.exports = router;
