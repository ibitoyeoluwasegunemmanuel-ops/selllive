// routes/wallet.js — Seller wallet & payout system
const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { authenticate, sellerOnly, adminOnly } = require('../middleware/auth');

// ============================================================
// GET /api/wallet — seller's wallet balance
// ============================================================
router.get('/', authenticate, sellerOnly, async (req, res) => {
  const { data: wallet, error } = await supabase
    .from('wallets')
    .select('*')
    .eq('seller_id', req.user.id)
    .single();

  if (error) return res.status(500).json({ error: 'Failed to fetch wallet.' });

  const { data: recentPayouts } = await supabase
    .from('payouts')
    .select('id, amount, status, requested_at, completed_at')
    .eq('seller_id', req.user.id)
    .order('requested_at', { ascending: false })
    .limit(10);

  res.json({
    wallet: {
      balance_naira: (wallet.balance || 0) / 100,
      total_earned_naira: (wallet.total_earned || 0) / 100,
      total_withdrawn_naira: (wallet.total_withdrawn || 0) / 100,
    },
    recent_payouts: recentPayouts || [],
  });
});

// ============================================================
// POST /api/wallet/withdraw — request a payout
// Minimum withdrawal: ₦1,000
// ============================================================
router.post('/withdraw', authenticate, sellerOnly, async (req, res) => {
  const { amount_naira } = req.body;

  if (!amount_naira || amount_naira < 1000) {
    return res.status(400).json({ error: 'Minimum withdrawal is ₦1,000.' });
  }

  const amountKobo = Math.floor(amount_naira * 100);

  // Check wallet balance
  const { data: wallet } = await supabase
    .from('wallets')
    .select('balance')
    .eq('seller_id', req.user.id)
    .single();

  if (!wallet || wallet.balance < amountKobo) {
    return res.status(400).json({ error: 'Insufficient balance.' });
  }

  // Get seller bank details
  const { data: profile } = await supabase
    .from('seller_profiles')
    .select('bank_account, bank_code, account_name')
    .eq('user_id', req.user.id)
    .single();

  if (!profile?.bank_account) {
    return res.status(400).json({ error: 'No bank account on file. Update your profile.' });
  }

  // Deduct from wallet immediately (hold funds)
  await supabase
    .from('wallets')
    .update({ balance: wallet.balance - amountKobo })
    .eq('seller_id', req.user.id);

  // Create payout record
  const { data: payout, error: payoutError } = await supabase
    .from('payouts')
    .insert({
      seller_id: req.user.id,
      amount: amountKobo,
      bank_account: profile.bank_account,
      bank_code: profile.bank_code,
      account_name: profile.account_name,
      status: 'pending',
    })
    .select()
    .single();

  if (payoutError) {
    // Restore balance on error
    await supabase.from('wallets').update({ balance: wallet.balance }).eq('seller_id', req.user.id);
    return res.status(500).json({ error: 'Failed to create payout.' });
  }

  // Initiate transfer via Flutterwave
  if (process.env.FLW_SECRET_KEY) {
    try {
      const flwResponse = await axios.post(
        'https://api.flutterwave.com/v3/transfers',
        {
          account_bank: profile.bank_code,
          account_number: profile.bank_account,
          amount: amount_naira,
          currency: 'NGN',
          narration: `SellLive payout - ${req.user.name}`,
          reference: `SL-PAY-${payout.id.split('-')[0]}`,
          callback_url: `${process.env.APP_URL}/webhook/flutterwave-transfer`,
          meta: { payout_id: payout.id, seller_id: req.user.id },
        },
        { headers: { Authorization: `Bearer ${process.env.FLW_SECRET_KEY}` } }
      );

      await supabase.from('payouts').update({
        status: 'processing',
        flw_transfer_id: String(flwResponse.data.data.id),
      }).eq('id', payout.id);

    } catch (flwErr) {
      console.error('Flutterwave transfer error:', flwErr.response?.data || flwErr.message);
      // Keep as pending — admin can process manually
    }
  }

  res.json({
    success: true,
    payout_id: payout.id,
    amount_naira,
    status: 'pending',
    message: `Withdrawal of ₦${amount_naira.toLocaleString()} is being processed. 1-2 business days.`,
  });
});

// ============================================================
// GET /api/wallet/banks — list Nigerian banks for Flutterwave
// ============================================================
router.get('/banks', async (req, res) => {
  try {
    if (process.env.FLW_SECRET_KEY) {
      const response = await axios.get(
        'https://api.flutterwave.com/v3/banks/NG',
        { headers: { Authorization: `Bearer ${process.env.FLW_SECRET_KEY}` } }
      );
      return res.json({ banks: response.data.data });
    }
    // Fallback: common Nigerian banks
    res.json({ banks: [
      { id: 1, code: '044', name: 'Access Bank' },
      { id: 2, code: '023', name: 'Citibank' },
      { id: 3, code: '063', name: 'Diamond Bank' },
      { id: 4, code: '050', name: 'EcoBank' },
      { id: 5, code: '070', name: 'Fidelity Bank' },
      { id: 6, code: '011', name: 'First Bank' },
      { id: 7, code: '214', name: 'First City Monument Bank' },
      { id: 8, code: '058', name: 'Guaranty Trust Bank' },
      { id: 9, code: '030', name: 'Heritage Bank' },
      { id: 10, code: '301', name: 'Jaiz Bank' },
      { id: 11, code: '082', name: 'Keystone Bank' },
      { id: 12, code: '014', name: 'MainStreet Bank' },
      { id: 13, code: '076', name: 'Polaris Bank' },
      { id: 14, code: '101', name: 'ProvidusBank' },
      { id: 15, code: '221', name: 'Stanbic IBTC Bank' },
      { id: 16, code: '068', name: 'Standard Chartered Bank' },
      { id: 17, code: '232', name: 'Sterling Bank' },
      { id: 18, code: '100', name: 'SunTrust Bank' },
      { id: 19, code: '032', name: 'Union Bank' },
      { id: 20, code: '033', name: 'United Bank For Africa' },
      { id: 21, code: '215', name: 'Unity Bank' },
      { id: 22, code: '035', name: 'Wema Bank' },
      { id: 23, code: '057', name: 'Zenith Bank' },
      { id: 24, code: '327', name: 'Palmpay' },
      { id: 25, code: '304', name: 'Opay' },
      { id: 26, code: '311', name: 'Kuda Bank' },
    ]});
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch banks.' });
  }
});

// ============================================================
// POST /api/wallet/verify-account — verify bank account name
// ============================================================
router.post('/verify-account', authenticate, async (req, res) => {
  const { account_number, account_bank } = req.body;
  if (!account_number || !account_bank) {
    return res.status(400).json({ error: 'account_number and account_bank required.' });
  }

  try {
    if (process.env.FLW_SECRET_KEY) {
      const response = await axios.post(
        'https://api.flutterwave.com/v3/accounts/resolve',
        { account_number, account_bank },
        { headers: { Authorization: `Bearer ${process.env.FLW_SECRET_KEY}` } }
      );
      return res.json({
        account_name: response.data.data.account_name,
        account_number: response.data.data.account_number,
      });
    }
    // Dev fallback
    res.json({ account_name: 'ACCOUNT HOLDER NAME', account_number });
  } catch (err) {
    res.status(400).json({ error: 'Could not verify account. Check the number and bank.' });
  }
});

// ============================================================
// ADMIN: GET /api/wallet/admin/payouts — all pending payouts
// ============================================================
router.get('/admin/payouts', authenticate, adminOnly, async (req, res) => {
  const { data: payouts } = await supabase
    .from('payouts')
    .select(`
      *, seller:users!seller_id(name, phone)
    `)
    .order('requested_at', { ascending: false })
    .limit(50);

  res.json({ payouts: payouts || [] });
});

module.exports = router;
