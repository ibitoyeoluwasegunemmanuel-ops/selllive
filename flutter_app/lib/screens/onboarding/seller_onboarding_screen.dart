// lib/screens/onboarding/seller_onboarding_screen.dart
// 3-step guided setup for new sellers: business details → bank account → first action
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class SellerOnboardingScreen extends StatefulWidget {
  const SellerOnboardingScreen({super.key});
  @override State<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> {
  final PageController _pages = PageController();
  int _step = 0;

  // Step 1 — Business details
  final _businessNameCtrl  = TextEditingController();
  final _categoryCtrl      = TextEditingController();
  final _descriptionCtrl   = TextEditingController();
  String _selectedCategory = 'Fashion';

  // Step 2 — Bank account
  final _accountNumberCtrl = TextEditingController();
  String? _selectedBank;
  String? _accountName;
  bool _isVerifyingBank = false;
  List<Map<String,dynamic>> _banks = [];

  bool _isSaving = false;

  final _categories = ['Fashion', 'Electronics', 'Beauty', 'Food', 'Fabric', 'Jewelry', 'Home', 'Shoes', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadBanks();
    // Pre-fill business name from registration
    final user = context.read<AuthService>().user;
    _businessNameCtrl.text = user?['name'] ?? '';
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await context.read<ApiService>().getBanks();
      setState(() => _banks = banks.cast<Map<String,dynamic>>());
    } catch (_) {}
  }

  Future<void> _verifyAccount() async {
    if (_accountNumberCtrl.text.length < 10 || _selectedBank == null) return;
    setState(() { _isVerifyingBank = true; _accountName = null; });
    try {
      final result = await context.read<ApiService>().verifyBankAccount(
        accountNumber: _accountNumberCtrl.text.trim(),
        bankCode: _selectedBank!,
      );
      setState(() => _accountName = result['account_name']);
    } catch (_) {
      setState(() => _accountName = 'Could not verify — check number');
    }
    setState(() => _isVerifyingBank = false);
  }

  Future<void> _saveStep1() async {
    if (_businessNameCtrl.text.trim().isEmpty) {
      _snack('Enter your business name');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<ApiService>().updateSellerProfile(
        businessName: _businessNameCtrl.text.trim(),
        category: _selectedCategory,
        description: _descriptionCtrl.text.trim(),
      );
      _nextStep();
    } catch (_) { _snack('Failed to save. Try again.'); }
    setState(() => _isSaving = false);
  }

  Future<void> _saveStep2() async {
    if (_accountNumberCtrl.text.length < 10 || _selectedBank == null || _accountName == null || _accountName!.contains('Could not')) {
      _snack('Please verify your bank account first');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<ApiService>().updateSellerProfile(
        bankAccount: _accountNumberCtrl.text.trim(),
        bankCode: _selectedBank!,
        accountName: _accountName!,
      );
      _nextStep();
    } catch (_) { _snack('Failed to save bank details. Try again.'); }
    setState(() => _isSaving = false);
  }

  void _nextStep() {
    if (_step < 2) {
      setState(() => _step++);
      _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // Mark onboarding complete and go to home
      context.read<AuthService>().updateUser({'onboarding_done': true});
      context.go('/home');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: SellLiveTheme.bgCard));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            _ProgressBar(step: _step, total: 3),
            // Pages
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _step1Business(),
                  _step2Bank(),
                  _step3Ready(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 1: Business Details ─────────────────────────────────
  Widget _step1Business() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('👋', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 16),
        const Text('Set up your shop', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Buyers will see this on your profile', style: TextStyle(color: SellLiveTheme.textSecondary)),
        const SizedBox(height: 32),

        _Label('Business / Shop Name'),
        TextField(
          controller: _businessNameCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "e.g. Ada's Ankara World"),
        ),
        const SizedBox(height: 20),

        _Label('Category'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((c) => GestureDetector(
            onTap: () => setState(() => _selectedCategory = c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedCategory == c ? SellLiveTheme.primaryOrange.withOpacity(0.15) : SellLiveTheme.bgCard,
                border: Border.all(color: _selectedCategory == c ? SellLiveTheme.primaryOrange : const Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(c, style: TextStyle(
                color: _selectedCategory == c ? SellLiveTheme.primaryOrange : SellLiveTheme.textSecondary,
                fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),

        _Label('Short Description (optional)'),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 2,
          maxLength: 150,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'What do you sell? e.g. Premium ankara fabrics and ready-to-wear from Lagos'),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveStep1,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Continue'),
          ),
        ),
      ],
    ),
  );

  // ── STEP 2: Bank Account ─────────────────────────────────────
  Widget _step2Bank() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('🏦', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 16),
        const Text('Add your bank account', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Payments go here within 24 hours of delivery', style: TextStyle(color: SellLiveTheme.textSecondary)),
        const SizedBox(height: 32),

        _Label('Select Bank'),
        Container(
          decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBank,
              hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Choose your bank', style: TextStyle(color: SellLiveTheme.textHint))),
              dropdownColor: SellLiveTheme.bgCard,
              isExpanded: true,
              icon: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.keyboard_arrow_down, color: SellLiveTheme.textHint)),
              items: _banks.map((b) => DropdownMenuItem<String>(
                value: b['code'] as String?,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(b['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              )).toList(),
              onChanged: (v) { setState(() { _selectedBank = v; _accountName = null; }); },
            ),
          ),
        ),
        const SizedBox(height: 16),

        _Label('Account Number'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _accountNumberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: '10-digit account number', counterText: ''),
                onChanged: (v) { if (v.length == 10 && _selectedBank != null) _verifyAccount(); },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isVerifyingBank ? null : _verifyAccount,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              child: _isVerifyingBank
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verify'),
            ),
          ],
        ),

        if (_accountName != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accountName!.contains('Could not') ? SellLiveTheme.error.withOpacity(0.1) : SellLiveTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accountName!.contains('Could not') ? SellLiveTheme.error.withOpacity(0.3) : SellLiveTheme.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(_accountName!.contains('Could not') ? Icons.error_outline : Icons.check_circle_outline,
                  color: _accountName!.contains('Could not') ? SellLiveTheme.error : SellLiveTheme.success, size: 18),
              const SizedBox(width: 8),
              Text(_accountName!, style: TextStyle(
                  color: _accountName!.contains('Could not') ? SellLiveTheme.error : SellLiveTheme.success,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ],

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
          child: const Row(children: [
            Icon(Icons.lock_outline, color: SellLiveTheme.primaryOrange, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Your bank details are encrypted and never shared with buyers.', style: TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveStep2,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Bank Account'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _nextStep,
            child: const Text('Skip for now', style: TextStyle(color: SellLiveTheme.textSecondary)),
          ),
        ),
      ],
    ),
  );

  // ── STEP 3: Ready to go ──────────────────────────────────────
  Widget _step3Ready() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Spacer(),
        const Text('🎉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        const Text("You're ready to sell!", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        const Text('Your shop is set up. Start by going live or creating a post.', style: TextStyle(color: SellLiveTheme.textSecondary, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 40),
        _ActionCard(icon: '🔴', title: 'Go Live Now', subtitle: 'Show products in real time to thousands of buyers', onTap: () { context.go('/go-live'); }),
        const SizedBox(height: 14),
        _ActionCard(icon: '📸', title: 'Create a Post', subtitle: 'Upload photos or videos of your products', onTap: () { context.go('/create-post'); }),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Explore the App'),
          ),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );
}

class _ActionCard extends StatelessWidget {
  final String icon, title, subtitle;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          Text(subtitle, style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12, height: 1.4)),
        ])),
        const Icon(Icons.chevron_right, color: SellLiveTheme.textHint),
      ]),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  final int step, total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step ${step + 1} of $total', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (step + 1) / total,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: const AlwaysStoppedAnimation<Color>(SellLiveTheme.primaryOrange),
            minHeight: 4,
          ),
        ),
      ],
    ),
  );
}
