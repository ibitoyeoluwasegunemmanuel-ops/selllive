// lib/screens/wallet/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  final _amountController = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final d = await context.read<ApiService>().getWallet();
      setState(() => _data = d);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 1000) {
      _showSnack('Minimum withdrawal is ₦1,000');
      return;
    }
    try {
      final result = await context.read<ApiService>().requestPayout(amountNaira: amount);
      _showSnack(result['message'] ?? 'Withdrawal requested!');
      _amountController.clear();
      Navigator.pop(context);
      _load();
    } catch (e) {
      _showSnack('Failed: ${e.toString()}');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: SellLiveTheme.bgCard));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(title: const Text('My Wallet')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : RefreshIndicator(
              color: SellLiveTheme.primaryOrange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Balance card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(
                          '₦${(_data?['wallet']?['balance_naira'] ?? 0).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _statItem('Total Earned', _data?['wallet']?['total_earned_naira']),
                            const SizedBox(width: 24),
                            _statItem('Withdrawn', _data?['wallet']?['total_withdrawn_naira']),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Withdraw button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showWithdrawSheet(),
                      icon: const Icon(Icons.account_balance),
                      label: const Text('Withdraw to Bank Account'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent payouts
                  const Text('Recent Payouts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...(_data?['recent_payouts'] as List? ?? []).map((p) => _PayoutTile(payout: p)),
                  if ((_data?['recent_payouts'] as List? ?? []).isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No payouts yet', style: TextStyle(color: SellLiveTheme.textHint)),
                    )),
                ],
              ),
            ),
    );
  }

  Widget _statItem(String label, dynamic value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      Text(
        '₦${(value ?? 0).toStringAsFixed(0)}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ],
  );

  void _showWithdrawSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdraw Funds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Available: ₦${(_data?['wallet']?['balance_naira'] ?? 0).toStringAsFixed(0)}',
                style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: const InputDecoration(
                hintText: 'Amount (₦)',
                prefixText: '₦ ',
                prefixStyle: TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Minimum: ₦1,000 · Paid within 1-2 business days', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _withdraw,
                child: const Text('Request Withdrawal'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final Map<String, dynamic> payout;
  const _PayoutTile({required this.payout});

  @override
  Widget build(BuildContext context) {
    final status = payout['status'] as String;
    final colors = {'pending': SellLiveTheme.warning, 'processing': SellLiveTheme.primaryOrange, 'completed': SellLiveTheme.success, 'failed': SellLiveTheme.error};
    final color = colors[status] ?? SellLiveTheme.textHint;
    final amountNaira = (payout['amount'] as int? ?? 0) / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(
        children: [
          Icon(Icons.account_balance, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₦${amountNaira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                Text(payout['requested_at']?.toString().split('T')[0] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
            child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
