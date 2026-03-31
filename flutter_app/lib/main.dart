// lib/main.dart — SellLive Flutter App Entry Point
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'router.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://your-project.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue: 'your-anon-key'),
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider(
          create: (ctx) => AuthService(
            apiService: ctx.read<ApiService>(),
            prefs: prefs,
          ),
        ),
      ],
      child: const SellLiveApp(),
    ),
  );
}

class SellLiveApp extends StatelessWidget {
  const SellLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SellLive',
      debugShowCheckedModeBanner: false,
      theme: SellLiveTheme.light,
      darkTheme: SellLiveTheme.dark,
      themeMode: ThemeMode.dark,  // Commerce apps look better dark
      routerConfig: appRouter(context.read<AuthService>()),
    );
  }
}
