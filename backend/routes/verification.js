// routes/verification.js — Seller identity verification
const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, sellerOnly, adminOnly } = require('../middleware/auth');

// POST /api/verification/submit
router.post('/submit', authenticate, sellerOnly, async (req, res) => {
  const { id_type, id_number, id_image_url, selfie_url } = req.body;
  if (!id_type || !id_number || !id_image_url) {
    return res.status(400).json({ error: 'id_type, id_number, and id_image_url required.' });
  }

  const { data, error } = await supabase.from('seller_verifications')
    .upsert({ seller_id: req.user.id, id_type, id_number, id_image_url, selfie_url, status: 'pending', submitted_at: new Date() },
      { onConflict: 'seller_id' })
    .select().single();

  if (error) return res.status(500).json({ error: 'Failed to submit verification.' });

  // Notify admin
  await supabase.from('notifications').insert({
    user_id: req.user.id, type: 'new_order',
    title: '📋 Verification Submitted',
    body: 'Your identity documents have been submitted. We will review within 24 hours.',
    data: { verification_id: data.id },
  });

  res.json({ success: true, status: 'pending', message: 'Documents submitted! Review takes up to 24 hours.' });
});

// GET /api/verification/status
router.get('/status', authenticate, async (req, res) => {
  const { data } = await supabase.from('seller_verifications')
    .select('status, rejection_reason, submitted_at, reviewed_at')
    .eq('seller_id', req.user.id).single();
  res.json({ verification: data || { status: 'not_submitted' } });
});

// ADMIN: PATCH /api/verification/:id — approve or reject
router.patch('/:id', authenticate, adminOnly, async (req, res) => {
  const { status, rejection_reason } = req.body;
  if (!['approved', 'rejected'].includes(status)) return res.status(400).json({ error: 'Invalid status.' });

  const { data: v } = await supabase.from('seller_verifications')
    .update({ status, rejection_reason, reviewed_at: new Date() })
    .eq('id', req.params.id).select('seller_id').single();

  if (status === 'approved') {
    await supabase.from('seller_profiles').update({ is_verified: true }).eq('user_id', v.seller_id);
  }

  await supabase.from('notifications').insert({
    user_id: v.seller_id, type: 'new_review',
    title: status === 'approved' ? '✅ Account Verified!' : '❌ Verification Rejected',
    body: status === 'approved' ? 'Your seller account is now verified. Buyers will see a verified badge.' : `Reason: ${rejection_reason}`,
  });

  res.json({ success: true, status });
});

// ADMIN: GET /api/verification/pending
router.get('/pending', authenticate, adminOnly, async (req, res) => {
  const { data } = await supabase.from('seller_verifications')
    .select('*, seller:users!seller_id(name, phone)')
    .eq('status', 'pending').order('submitted_at');
  res.json({ verifications: data || [] });
});

module.exports = router;
