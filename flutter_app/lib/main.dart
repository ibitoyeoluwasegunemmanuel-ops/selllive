// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router.dart';
import 'theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

const _supabaseUrl  = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://aayprwxhzbhmghvgaeyi.supabase.co');
const _supabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFheXByd3hoemJobWdodmdhZXlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MjM4NzIsImV4cCI6MjA5MDQ5OTg3Mn0.zXpJT9lqmpnPmEFaZTfWg1k8Iq4_yLfyhMLGQxf6qJ0');
const _apiBase      = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://selllive.vercel.app/api');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnon);

  runApp(const SellLiveApp());
}

class SellLiveApp extends StatelessWidget {
  const SellLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, ApiService>(
          create: (_) => ApiService(baseUrl: _apiBase, token: null),
          update: (_, auth, prev) => ApiService(
            baseUrl: _apiBase,
            token: auth.token,
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final auth   = context.watch<AuthService>();
          final router = buildRouter(auth);
          return MaterialApp.router(
            title: 'SellLive',
            debugShowCheckedModeBanner: false,
            theme: SellLiveTheme.dark,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
