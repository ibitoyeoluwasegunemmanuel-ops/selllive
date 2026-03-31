// lib/router.dart — App navigation
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/stream/watch_stream_screen.dart';
import 'screens/seller/go_live_screen.dart';
import 'screens/seller/dashboard_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/profile/profile_screen.dart';

GoRouter appRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authService.isLoggedIn;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute && state.matchedLocation != '/') {
        return '/auth/phone';
      }
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    refreshListenable: authService,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),

      // Auth flow
      GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, state) => RegisterScreen(data: state.extra as Map<String, dynamic>),
      ),

      // Main app (shell route with bottom nav)
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/seller/dashboard',
            builder: (_, __) => const SellerDashboardScreen(),
          ),
        ],
      ),

      // Stream screens (full screen, no bottom nav)
      GoRoute(
        path: '/stream/:id',
        builder: (_, state) => WatchStreamScreen(streamId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/go-live',
        builder: (_, __) => const GoLiveScreen(),
      ),
    ],
  );
}

// Bottom navigation shell
class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // Determine current index based on route
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/orders')) currentIndex = 1;
    if (location.startsWith('/seller/dashboard')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0: context.go('/home'); break;
            case 1: context.go('/orders'); break;
            case 2: context.go('/seller/dashboard'); break;
            case 3: context.go('/profile'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Sell'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
