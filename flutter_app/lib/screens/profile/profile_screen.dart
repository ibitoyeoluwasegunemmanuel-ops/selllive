// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final isSeller = user?['role'] == 'seller';

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 8),
            _buildHeader(context, user, isSeller),
            const SizedBox(height: 20),

            if (isSeller) ...[
              _label('SELLER TOOLS'),
              _tile(context, Icons.live_tv, 'Go Live', const Color(0xFFFF1744), '/go-live'),
              _tile(context, Icons.inventory_2_outlined, 'My Products', const Color(0xFF4CAF50), '/seller/products'),
              _tile(context, Icons.bar_chart_rounded, 'Analytics', const Color(0xFF2196F3), '/analytics'),
              _tile(context, Icons.account_balance_wallet_outlined, 'Wallet & Payouts', const Color(0xFF9C27B0), '/wallet'),
              _tile(context, Icons.verified_outlined, 'Get Verified', const Color(0xFF00BCD4), '/verification'),
              const SizedBox(height: 12),
            ],

            _label('SHOPPING'),
            _tile(context, Icons.shopping_bag_outlined, 'My Orders', SellLiveTheme.primaryOrange, '/orders'),
            _tile(context, Icons.location_on_outlined, 'Delivery Addresses', const Color(0xFF4CAF50), '/addresses'),
            _tileAction(context, Icons.star_outline, 'Loyalty Points', const Color(0xFFFF9800), () => _showPoints(context)),
            const SizedBox(height: 12),

            _label('DISCOVER'),
            _tile(context, Icons.flash_on_outlined, 'Flash Sales', const Color(0xFFFF1744), '/flash-sales'),
            _tile(context, Icons.card_giftcard_outlined, 'Refer & Earn ₦500', const Color(0xFF4CAF50), '/referral'),
            _tile(context, Icons.chat_bubble_outline, 'Messages', const Color(0xFF2196F3), '/messages'),
            const SizedBox(height: 12),

            _label('ACCOUNT'),
            _tileAction(context, Icons.person_outline, 'Edit Profile', SellLiveTheme.textSecondary, () => _editProfile(context, user)),
            _tileAction(context, Icons.gavel_outlined, 'Open Dispute', const Color(0xFFF44336), () => context.push('/disputes')),
            const SizedBox(height: 16),

            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: SellLiveTheme.error, size: 18),
              label: const Text('Log Out', style: TextStyle(color: SellLiveTheme.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: SellLiveTheme.error), padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
            const SizedBox(height: 12),
            const Text('SellLive v1.0 · Made in Lagos 🇳🇬', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String,dynamic>? user, bool isSeller) {
    final name = user?['name'] ?? 'User';
    return Row(children: [
      CircleAvatar(radius: 28, backgroundColor: SellLiveTheme.primaryOrange,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        Text(user?['phone'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
        if (isSeller) ...[
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: SellLiveTheme.primaryOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: SellLiveTheme.primaryOrange.withOpacity(0.4))),
              child: const Text('🏪 Seller', style: TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w700))),
        ],
      ])),
      IconButton(icon: const Icon(Icons.notifications_outlined, color: SellLiveTheme.textSecondary), onPressed: () {}),
    ]);
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(t, style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))));

  Widget _tile(BuildContext context, IconData icon, String label, Color color, String route) =>
      _tileAction(context, icon, label, color, () => context.push(route));

  Widget _tileAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, color: SellLiveTheme.textHint, size: 17),
        ]),
      ));

  void _showPoints(BuildContext context) async {
    try {
      final data = await context.read<ApiService>().get('/loyalty');
      if (!context.mounted) return;
      showModalBottomSheet(context: context, backgroundColor: SellLiveTheme.bgCard,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏆', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text('${data['points']} Points', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            Text('Worth ₦${data['naira_value']}', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${data['points_to_next']} more points to next ₦500 reward', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            if ((data['rewards_available'] as int? ?? 0) > 0)
              ElevatedButton(onPressed: () {}, child: const Text('Redeem 100 pts for ₦500')),
          ])));
    } catch (_) {}
  }

  void _editProfile(BuildContext context, Map<String,dynamic>? user) {
    final ctrl = TextEditingController(text: user?['name'] ?? '');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: SellLiveTheme.bgCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 14),
            TextField(controller: ctrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Name', hintText: 'Your full name')),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
              await context.read<ApiService>().post('/auth/update-profile', {'name': ctrl.text.trim()});
              context.read<AuthService>().updateUser({'name': ctrl.text.trim()});
              if (context.mounted) Navigator.pop(context);
            }, child: const Text('Save'))),
          ]),
        ));
  }

  void _logout(BuildContext context) => showDialog(context: context, builder: (_) => AlertDialog(
    backgroundColor: SellLiveTheme.bgCard,
    title: const Text('Log Out?', style: TextStyle(color: Colors.white)),
    content: const Text('You will need to enter your phone number again.', style: TextStyle(color: SellLiveTheme.textSecondary)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      TextButton(onPressed: () async { Navigator.pop(context); await context.read<AuthService>().logout(); },
          child: const Text('Log Out', style: TextStyle(color: SellLiveTheme.error))),
    ],
  ));
}
