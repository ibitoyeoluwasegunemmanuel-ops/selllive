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

// Send SMS via Termii (Nigerian SMS gateway)
// If no Termii key is configured, OTP is returned in the API response directly
const sendSMS = async (phone, message) => {
  if (!process.env.TERMII_API_KEY) {
    console.log(`📱 NO SMS KEY — OTP for ${phone}: ${message}`);
    return false; // signals caller to include OTP in response
  }
  try {
    await axios.post('https://api.ng.termii.com/api/sms/send', {
      to: phone,
      from: process.env.TERMII_SENDER_ID || 'SellLive',
      sms: message,
      type: 'plain',
      channel: 'generic',
      api_key: process.env.TERMII_API_KEY,
    });
    return true;
  } catch (err) {
    console.error('SMS failed:', err.message);
    console.log(`📱 SMS FALLBACK OTP for ${phone}: ${message}`);
    return false;
  }
};

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

  // Send SMS — returns false if no Termii key configured
  const smsMessage = `Your SellLive verification code is: ${code}. Valid for 10 minutes. Do not share this code.`;
  const smsSent = await sendSMS(phone, smsMessage);

  res.json({
    success: true,
    message: smsSent ? `OTP sent to ${phone}` : `OTP ready for ${phone}`,
    ...(!smsSent && { code }),
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
