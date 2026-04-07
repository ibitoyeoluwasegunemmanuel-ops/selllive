// lib/router.dart — GoRouter navigation for SellLive
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/stream/watch_stream_screen.dart';
import 'screens/seller/go_live_screen.dart';
import 'screens/seller/dashboard_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/feed/shop_feed_screen.dart';
import 'screens/feed/create_post_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/call_screen.dart';
import 'screens/features/features_screens.dart';

// Shell navigator key for bottom nav
final _shellKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Splash ────────────────────────────────────────────
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),

    // ── Auth ──────────────────────────────────────────────
    GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneScreen()),
    GoRoute(
      path: '/auth/otp',
      builder: (_, state) => OtpScreen(phone: state.extra as String? ?? ''),
    ),
    GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),

    // ── Main shell with bottom nav ─────────────────────────
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home',   builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/feed',   builder: (_, __) => const ShopFeedScreen()),
        GoRoute(path: '/explore',builder: (_, __) => const ExploreScreen()),
        GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
        GoRoute(path: '/profile',builder: (_, __) => const ProfileScreen()),
      ],
    ),

    // ── Streams ───────────────────────────────────────────
    GoRoute(
      path: '/stream/:id',
      builder: (_, state) => WatchStreamScreen(streamId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/go-live', builder: (_, __) => const GoLiveScreen()),

    // ── Seller ────────────────────────────────────────────
    GoRoute(path: '/seller/dashboard', builder: (_, __) => const SellerDashboardScreen()),

    // ── Wallet ───────────────────────────────────────────
    GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),

    // ── Feed posts ───────────────────────────────────────
    GoRoute(path: '/create-post', builder: (_, __) => const CreatePostScreen()),

    // ── Chat ─────────────────────────────────────────────
    GoRoute(path: '/messages', builder: (_, __) => const ChatListScreen()),
    GoRoute(
      path: '/chat/:id',
      builder: (_, state) => ConversationScreen(
        conversationId: state.pathParameters['id']!,
        initialData: state.extra as Map<String, dynamic>?,
      ),
    ),

    // ── Calls ─────────────────────────────────────────────
    GoRoute(
      path: '/call/:id',
      builder: (_, state) => CallScreen(
        callId: state.pathParameters['id']!,
        callData: state.extra as Map<String, dynamic>? ?? {},
      ),
    ),

    // ── Features ─────────────────────────────────────────
    GoRoute(path: '/flash-sales',  builder: (_, __) => const FlashSalesScreen()),
    GoRoute(path: '/referral',     builder: (_, __) => const ReferralScreen()),
    GoRoute(path: '/addresses',    builder: (_, __) => const AddressBookScreen()),
    GoRoute(
      path: '/disputes',
      builder: (_, state) => DisputesScreen(orderId: state.extra as String?),
    ),
    GoRoute(path: '/analytics',    builder: (_, __) => const AnalyticsScreen()),
  ],
);

// ============================================================
// MAIN SHELL — bottom navigation bar
// ============================================================
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({required this.child, super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _tabs = ['/home', '/feed', '/explore', '/orders', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          context.go(_tabs[i]);
        },
        backgroundColor: const Color(0xFF111111),
        indicatorColor: const Color(0xFFFF5722).withOpacity(0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.grid_on_outlined), selectedIcon: Icon(Icons.grid_on), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
