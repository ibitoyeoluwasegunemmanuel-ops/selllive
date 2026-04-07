// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
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
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          // Avatar + name
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: SellLiveTheme.primaryOrange,
                  child: Text(
                    (user?['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?['name'] ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      Text(user?['phone'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: SellLiveTheme.primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                        child: Text(isSeller ? '🛍️ Seller' : '🛒 Buyer',
                            style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E1E1E)),

          // Seller features
          if (isSeller) ...[
            _Section(title: 'Seller Tools', items: [
              _Item(icon: Icons.dashboard, label: 'Dashboard', onTap: () => context.push('/seller/dashboard')),
              _Item(icon: Icons.account_balance_wallet, label: 'Wallet & Payouts', onTap: () => context.push('/wallet')),
              _Item(icon: Icons.bar_chart, label: 'Analytics', onTap: () => context.push('/analytics')),
              _Item(icon: Icons.flash_on, label: 'Flash Sales', badge: 'NEW', onTap: () => context.push('/flash-sales')),
              _Item(icon: Icons.live_tv, label: 'Go Live', onTap: () => context.push('/go-live')),
            ]),
          ],

          // Buyer features
          _Section(title: 'Shopping', items: [
            _Item(icon: Icons.shopping_bag_outlined, label: 'My Orders', onTap: () => context.push('/orders')),
            _Item(icon: Icons.location_on_outlined, label: 'Address Book', onTap: () => context.push('/addresses')),
            _Item(icon: Icons.shield_outlined, label: 'Disputes', onTap: () => context.push('/disputes')),
          ]),

          // Social
          _Section(title: 'Social', items: [
            _Item(icon: Icons.chat_bubble_outline, label: 'Messages', onTap: () => context.push('/messages')),
            _Item(icon: Icons.card_giftcard, label: 'Refer & Earn ₦500', badge: '₦500', onTap: () => context.push('/referral')),
          ]),

          // Account
          _Section(title: 'Account', items: [
            _Item(icon: Icons.logout, label: 'Sign Out', color: SellLiveTheme.error,
              onTap: () async {
                await context.read<AuthService>().logout();
                if (context.mounted) context.go('/auth/phone');
              }),
          ]),

          const SizedBox(height: 32),
          const Center(child: Text('SellLive v1.0 · Made in Nigeria 🇳🇬', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 11))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title.toUpperCase(), style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: items),
      ),
    ],
  );
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? color;
  final VoidCallback onTap;

  const _Item({required this.icon, required this.label, required this.onTap, this.badge, this.color});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color ?? SellLiveTheme.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: SellLiveTheme.primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
              child: Text(badge!, style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 4),
          if (badge == null) const Icon(Icons.chevron_right, color: SellLiveTheme.textHint, size: 18),
        ],
      ),
    ),
  );
}
