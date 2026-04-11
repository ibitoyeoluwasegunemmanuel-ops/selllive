// routes/auth.js — Phone OTP authentication
// Flow: Enter phone → Receive SMS → Verify code → Get JWT
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const axios = require('axios');
const Joi = require('joi');
const supabase = require('../config/supabase');

// ============================================================
// HELPERS
// ============================================================

// Generate 6-digit OTP
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

// Generate JWT token (valid for 30 days)
const generateToken = (userId) => jwt.sign(
  { userId },
  process.env.JWT_SECRET,
  { expiresIn: '30d' }
);

// Send SMS — tries Sendchamp first, Termii fallback, then dev mode
const sendOTP = async (phone, otp) => {
  // Normalize Nigerian number
  let to = phone.replace(/\s+/g, '');
  if (to.startsWith('0')) to = '+234' + to.slice(1);
  if (!to.startsWith('+')) to = '+234' + to;

  const smsMessage = `Your SellLive OTP is: ${otp}\n\nValid for 10 minutes. Do not share this code.`;
  const waMessage = `🔐 *SellLive Verification*\n\nYour OTP code is: *${otp}*\n\nValid for 10 minutes. Do not share this code.\n\n_If you did not request this, ignore._`;

  // 1. WhatsApp OTP via Sendchamp (bypasses DND completely — most reliable in Nigeria)
  if (process.env.SENDCHAMP_API_KEY) {
    const key = process.env.SENDCHAMP_API_KEY;
    try {
      const resp = await axios.post('https://api.sendchamp.com/api/v1/whatsapp/message/send', {
        sender: process.env.SENDCHAMP_WHATSAPP_SENDER || '2348000000000',
        message: waMessage,
        recipient: to.replace('+', ''),
        message_type: 'text',
      }, {
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        timeout: 12000,
      });
      const d = resp.data;
      console.log('Sendchamp WhatsApp OTP →', JSON.stringify(d).slice(0, 250));
      if (d?.code === '200' || d?.code === 200 || d?.data?.id || d?.status === 'success') {
        console.log(`✅ WhatsApp OTP sent to ${to}`);
        return { sent: true, channel: 'whatsapp' };
      }
      console.log('WhatsApp OTP failed, falling back to SMS...');
    } catch (err) {
      console.error('WhatsApp OTP error:', err.response?.data?.message || err.message);
    }

    // 2. SMS fallback — try non_dnd route (transactional, better DND penetration)
    for (const route of ['non_dnd', 'dnd', 'international']) {
      try {
        const resp = await axios.post('https://api.sendchamp.com/api/v1/sms/send', {
          to: [to],
          message: smsMessage,
          sender_name: 'SC-OTP',
          route,
        }, {
          headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
          timeout: 12000,
        });
        const d = resp.data;
        console.log(`Sendchamp SMS [${route}] →`, JSON.stringify(d).slice(0, 250));
        if (d?.code === '200' || d?.code === 200 || d?.data?.id) {
          console.log(`✅ SMS OTP sent via ${route} to ${to}`);
          return { sent: true, channel: 'sms' };
        }
        const msg = (d?.message || '').toLowerCase();
        if (msg.includes('balance') || msg.includes('fund') || msg.includes('credit')) {
          console.error('Sendchamp low balance:', d?.message);
          break;
        }
      } catch (err) {
        console.error(`SMS [${route}] error:`, err.response?.data?.message || err.message);
      }
    }
  }

  // 3. Termii fallback
  if (process.env.TERMII_API_KEY) {
    try {
      const resp = await axios.post('https://api.ng.termii.com/api/sms/send', {
        api_key: process.env.TERMII_API_KEY,
        to,
        from: 'N-Alert',
        sms: smsMessage,
        type: 'plain',
        channel: 'dnd',
      });
      console.log('Termii OTP:', JSON.stringify(resp.data).slice(0, 200));
      if (resp.data?.message_id || resp.data?.code === 'ok') {
        return { sent: true, channel: 'termii' };
      }
    } catch (err) {
      console.error('Termii error:', err.response?.data || err.message);
    }
  }

  // 4. Always show code on screen in dev/fallback mode
  console.log(`📱 OTP FALLBACK — code for ${to}: ${otp}`);
  return { sent: false, channel: 'screen' };
};
// alias
const sendSMS = sendOTP;

// ============================================================
// POST /api/auth/send-otp
// Send OTP to phone number
// ============================================================
router.post('/send-otp', async (req, res) => {
  const schema = Joi.object({
    phone: Joi.string().pattern(/^\+?[0-9]{10,15}$/).required(),
  });

  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { phone } = value;

  // Generate OTP
  const code = generateOTP();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

  // Delete old OTPs for this phone
  await supabase.from('otp_codes').delete().eq('phone', phone);

  // Store new OTP
  const { error: dbError } = await supabase.from('otp_codes').insert({
    phone,
    code,
    expires_at: expiresAt.toISOString(),
  });

  if (dbError) {
    return res.status(500).json({ error: 'Failed to create OTP. Try again.' });
  }

  // Send OTP via WhatsApp first, then SMS fallback
  const result = await sendOTP(phone, code);
  const delivered = result?.sent || false;
  const channel = result?.channel || 'screen';

  console.log(`OTP result: delivered=${delivered}, channel=${channel}, code=${code}`);

  res.json({
    success: true,
    delivered,
    channel,
    message: delivered
      ? `OTP sent via ${channel} to ${phone}`
      : `OTP ready — check the code shown on screen`,
    // ALWAYS include code so it shows on screen — users can read it if SMS fails
    code,
  });
});

// ============================================================
// POST /api/auth/verify-otp
// Verify OTP and register/login user
// ============================================================
router.post('/verify-otp', async (req, res) => {
  const schema = Joi.object({
    phone: Joi.string().required(),
    code: Joi.string().length(6).required(),
    name: Joi.string().min(2).max(100),  // required for new users
    role: Joi.string().valid('buyer', 'seller').default('buyer'),
  });

  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { phone, code, name, role } = value;

  // Find valid OTP
  const { data: otpRecord } = await supabase
    .from('otp_codes')
    .select('*')
    .eq('phone', phone)
    .eq('code', code)
    .eq('used', false)
    .gte('expires_at', new Date().toISOString())
    .single();

  if (!otpRecord) {
    return res.status(400).json({ error: 'Invalid or expired code. Request a new one.' });
  }

  // Mark OTP as used
  await supabase.from('otp_codes').update({ used: true }).eq('id', otpRecord.id);

  // Check if user exists
  let { data: user } = await supabase
    .from('users')
    .select('*')
    .eq('phone', phone)
    .single();

  const isNewUser = !user;

  if (isNewUser) {
    // Require name for registration
    if (!name) {
      return res.status(400).json({
        error: 'Name is required for new accounts.',
        is_new_user: true,
      });
    }

    // Create new user
    const { data: newUser, error: createError } = await supabase
      .from('users')
      .insert({ phone, name, role, is_verified: true })
      .select()
      .single();

    if (createError) {
      return res.status(500).json({ error: 'Failed to create account.' });
    }

    user = newUser;

    // If seller, create seller profile
    if (role === 'seller') {
      await supabase.from('seller_profiles').insert({
        user_id: user.id,
        business_name: name,
      });
    }
  }

  // Generate token
  const token = generateToken(user.id);

  res.json({
    success: true,
    is_new_user: isNewUser,
    token,
    user: {
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
    },
  });
});

// ============================================================
// POST /api/auth/complete-seller-profile
// Seller fills in business details after registration
// ============================================================
const { authenticate } = require('../middleware/auth');

router.post('/complete-seller-profile', authenticate, async (req, res) => {
  const schema = Joi.object({
    business_name: Joi.string().min(2).max(150).required(),
    bio: Joi.string().max(500),
    bank_account: Joi.string().min(10).max(10).required(),
    bank_code: Joi.string().required(),
    account_name: Joi.string().required(),
  });

  const { error, value } = schema.validate(req.body);
  if (error) return res.status(400).json({ error: error.details[0].message });

  const { error: updateError } = await supabase
    .from('seller_profiles')
    .upsert({ user_id: req.user.id, ...value });

  if (updateError) {
    return res.status(500).json({ error: 'Failed to save profile.' });
  }

  res.json({ success: true, message: 'Profile saved! Awaiting verification.' });
});

module.exports = router;

// ============================================================
// POST /api/auth/update-profile — update seller profile
// ============================================================
router.post('/update-profile', require('../middleware/auth').authenticate, async (req, res) => {
  const { business_name, category, description, bank_account, bank_code, account_name, pickup_address } = req.body;

  if (business_name || category || description || pickup_address) {
    await supabase.from('seller_profiles').upsert({
      user_id: req.user.id,
      business_name: business_name || req.user.name,
      category, description, pickup_address,
    }, { onConflict: 'user_id' });
  }

  if (bank_account && bank_code && account_name) {
    await supabase.from('seller_profiles').update({ bank_account, bank_code, account_name })
      .eq('user_id', req.user.id);
  }

  res.json({ success: true });
});

// ============================================================
// GET /api/auth/seller/:id — public seller profile
// ============================================================
router.get('/seller/:id', async (req, res) => {
  const { id } = req.params;

  const { data: profile } = await supabase.from('seller_profiles')
    .select(`*, user:users!user_id(id, name, avatar_url, phone, created_at)`)
    .eq('user_id', id).single();

  if (!profile) return res.status(404).json({ error: 'Seller not found.' });

  res.json({ profile, user: profile.user });
});

// ============================================================
// GET /api/auth/search — unified search
// ============================================================
router.get('/search', async (req, res) => {
  const { q } = req.query;
  if (!q || q.length < 2) return res.status(400).json({ error: 'Query too short.' });

  const [streams, sellers, posts] = await Promise.all([
    supabase.from('streams').select(`id, title, viewer_count, status, thumbnail_url,
      seller:users!seller_id(name, avatar_url),
      seller_profile:seller_profiles!seller_id(business_name)`)
      .ilike('title', `%${q}%`).in('status', ['live', 'scheduled']).limit(10),

    supabase.from('seller_profiles').select(`business_name, category, is_verified, avg_rating, followers_count,
      user:users!user_id(id, name, avatar_url)`)
      .ilike('business_name', `%${q}%`).limit(10),

    supabase.from('posts').select(`id, caption, media_url, media_type, thumbnail_url, like_count, view_count,
      products:post_products(id, name, price, image_url)`)
      .ilike('caption', `%${q}%`).eq('is_active', true).limit(10),
  ]);

  res.json({
    streams: streams.data || [],
    sellers: sellers.data || [],
    posts:   posts.data   || [],
  });
});
