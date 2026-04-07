// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _user;
  String? _token;
  bool _loaded = false;

  Map<String, dynamic>? get user  => _user;
  String?               get token => _token;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isLoaded   => _loaded;

  // ── Load persisted session on app start ──────────────────────
  Future<void> loadUser() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('auth_token');
      final u = prefs.getString('auth_user');
      if (t != null && u != null) {
        _token = t;
        _user  = jsonDecode(u) as Map<String, dynamic>;
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  // ── Request OTP ──────────────────────────────────────────────
  Future<Map<String, dynamic>> sendOTP(String phone) async {
    final api = ApiService(baseUrl: _apiBase, token: null);
    final res = await api.post('/auth/send-otp', {'phone': phone});
    return res;
  }

  // ── Verify OTP — returns true if new user (needs name) ───────
  Future<bool> verifyOTP({
    required String phone,
    required String code,
    String role = 'buyer',
    String? name,
    String? businessName,
  }) async {
    final api = ApiService(baseUrl: _apiBase, token: null);
    final body = <String, dynamic>{'phone': phone, 'code': code, 'role': role};
    if (name != null)         body['name']          = name;
    if (businessName != null) body['business_name'] = businessName;

    final res = await api.post('/auth/verify-otp', body);

    final token = res['token'] as String?;
    final user  = res['user']  as Map<String, dynamic>?;
    final isNew = res['is_new_user'] == true;

    if (token != null && user != null) {
      await _persist(token, user);
    }

    return isNew;
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> logout() async {
    _token = null;
    _user  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    notifyListeners();
  }

  // ── Update user data locally (after profile edits) ───────────
  void updateUser(Map<String, dynamic> updates) {
    if (_user == null) return;
    _user = {..._user!, ...updates};
    _saveUser(_user!);
    notifyListeners();
  }

  // ── Persist to SharedPreferences ─────────────────────────────
  Future<void> _persist(String token, Map<String, dynamic> user) async {
    _token = token;
    _user  = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user', jsonEncode(user));
  }

  static const _apiBase = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'https://selllive.vercel.app/api');
}
