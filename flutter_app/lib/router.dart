// lib/router.dart — SellLive navigation with auth guards
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
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
import 'screens/onboarding/seller_onboarding_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/seller_profile/seller_profile_screen.dart';

final _rootKey  = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

GoRouter buildRouter(AuthService auth) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = auth.isLoggedIn;
    final onAuth   = state.matchedLocation.startsWith('/auth');
    final onSplash = state.matchedLocation == '/';
    if (onSplash) return null;
    if (!loggedIn && !onAuth) return '/auth/phone';
    if (loggedIn && onAuth)  return '/home';
    return null;
  },
  refreshListenable: auth,
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/auth/phone', parentNavigatorKey: _rootKey, builder: (_, __) => const PhoneScreen()),
    GoRoute(path: '/auth/otp',   parentNavigatorKey: _rootKey,
      builder: (_, state) => OtpScreen(data: state.extra as Map<String,dynamic>? ?? {'phone':'','role':'buyer'})),
    GoRoute(path: '/auth/register', parentNavigatorKey: _rootKey,
      builder: (_, state) => RegisterScreen(data: state.extra as Map<String,dynamic>? ?? {'phone':'','role':'buyer'})),
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/feed',    builder: (_, __) => const ShopFeedScreen()),
        GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
        GoRoute(path: '/orders',  builder: (_, __) => const OrdersScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    GoRoute(path: '/stream/:id', parentNavigatorKey: _rootKey,
      builder: (_, state) => WatchStreamScreen(streamId: state.pathParameters['id']!)),
    GoRoute(path: '/go-live',       parentNavigatorKey: _rootKey, builder: (_, __) => const GoLiveScreen()),
    GoRoute(path: '/seller/dashboard', parentNavigatorKey: _rootKey, builder: (_, __) => const SellerDashboardScreen()),
    GoRoute(path: '/wallet',        parentNavigatorKey: _rootKey, builder: (_, __) => const WalletScreen()),
    GoRoute(path: '/create-post',   parentNavigatorKey: _rootKey, builder: (_, __) => const CreatePostScreen()),
    GoRoute(path: '/messages',      parentNavigatorKey: _rootKey, builder: (_, __) => const ChatListScreen()),
    GoRoute(path: '/chat/:id',      parentNavigatorKey: _rootKey,
      builder: (_, state) => ConversationScreen(
        conversationId: state.pathParameters['id']!,
        initialData: state.extra as Map<String,dynamic>?)),
    GoRoute(path: '/call/:id',      parentNavigatorKey: _rootKey,
      builder: (_, state) => CallScreen(
        callId: state.pathParameters['id']!,
        callData: state.extra as Map<String,dynamic>? ?? {})),
    GoRoute(path: '/flash-sales',   parentNavigatorKey: _rootKey, builder: (_, __) => const FlashSalesScreen()),
    GoRoute(path: '/referral',      parentNavigatorKey: _rootKey, builder: (_, __) => const ReferralScreen()),
    GoRoute(path: '/addresses',     parentNavigatorKey: _rootKey, builder: (_, __) => const AddressBookScreen()),
    GoRoute(path: '/disputes',      parentNavigatorKey: _rootKey,
      builder: (_, state) => DisputesScreen(orderId: state.extra as String?)),
    GoRoute(path: '/analytics',     parentNavigatorKey: _rootKey, builder: (_, __) => const AnalyticsScreen()),
    GoRoute(path: '/onboarding/seller', parentNavigatorKey: _rootKey, builder: (_, __) => const SellerOnboardingScreen()),
    GoRoute(path: '/search',            parentNavigatorKey: _rootKey,
      builder: (_, state) => SearchScreen(initialQuery: state.extra as String?)),
    GoRoute(path: '/seller/:id',        parentNavigatorKey: _rootKey,
      builder: (_, state) => SellerProfileScreen(sellerId: state.pathParameters['id']!)),
  ],
);

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
        onDestinationSelected: (i) { setState(() => _index = i); context.go(_tabs[i]); },
        backgroundColor: const Color(0xFF111111),
        indicatorColor: const Color(0xFFFF5722).withOpacity(0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.grid_on_outlined), selectedIcon: Icon(Icons.grid_on), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
