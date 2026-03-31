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

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: SellLiveTheme.bgDark,
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline,
                  color: SellLiveTheme.textHint, size: 64),
              const SizedBox(height: 16),
              const Text('Sign in to view your profile',
                  style: TextStyle(color: SellLiveTheme.textPrimary, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.push('/auth/phone'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user!;

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: SellLiveTheme.primaryOrange,
                  child: Text(
                    (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(user['phone'] ?? '',
                    style: const TextStyle(
                        color: SellLiveTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: auth.isSeller
                        ? SellLiveTheme.primaryOrange.withOpacity(0.15)
                        : SellLiveTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.isSeller ? 'Seller Account' : 'Buyer Account',
                    style: TextStyle(
                      color: auth.isSeller
                          ? SellLiveTheme.primaryOrange
                          : SellLiveTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Menu items
          _MenuItem(
            icon: Icons.receipt_long,
            label: 'My Orders',
            onTap: () => context.go('/orders'),
          ),
          if (auth.isSeller) ...[
            _MenuItem(
              icon: Icons.dashboard,
              label: 'Seller Dashboard',
              onTap: () => context.go('/seller/dashboard'),
            ),
            _MenuItem(
              icon: Icons.live_tv,
              label: 'Go Live',
              onTap: () => context.push('/go-live'),
              accent: true,
            ),
          ],
          _MenuItem(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.info_outline,
            label: 'About SellLive',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.logout,
            label: 'Log Out',
            isDestructive: true,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: SellLiveTheme.bgCard,
                  title: const Text('Log out?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      'You\'ll need to verify your phone again to log back in.',
                      style: TextStyle(color: SellLiveTheme.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        auth.logout();
                        context.go('/auth/phone');
                      },
                      child: const Text('Log Out',
                          style: TextStyle(color: SellLiveTheme.error)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('SellLive v1.0.0 · Made in Nigeria 🇳🇬',
                style: TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool accent;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? SellLiveTheme.error
        : accent
            ? SellLiveTheme.primaryOrange
            : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SellLiveTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: color, fontSize: 15)),
            ),
            Icon(Icons.chevron_right,
                color: SellLiveTheme.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
