// lib/services/auth_service.dart — Auth state management
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService apiService;
  final SharedPreferences prefs;

  Map<String, dynamic>? _user;
  bool _isLoading = false;

  AuthService({required this.apiService, required this.prefs}) {
    _loadUserFromStorage();
  }

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isSeller => _user?['role'] == 'seller';

  void _loadUserFromStorage() {
    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_name');
    final userPhone = prefs.getString('user_phone');
    final userRole = prefs.getString('user_role');

    if (userId != null) {
      _user = {
        'id': userId,
        'name': userName,
        'phone': userPhone,
        'role': userRole,
      };
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendOTP(String phone) async {
    return await apiService.sendOTP(phone);
  }

  Future<bool> verifyOTP({
    required String phone,
    required String code,
    String? name,
    String role = 'buyer',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await apiService.verifyOTP(
        phone: phone,
        code: code,
        name: name,
        role: role,
      );

      // Save token and user data
      await prefs.setString('auth_token', result['token']);
      await prefs.setString('user_id', result['user']['id']);
      await prefs.setString('user_name', result['user']['name']);
      await prefs.setString('user_phone', result['user']['phone']);
      await prefs.setString('user_role', result['user']['role']);

      _user = result['user'];
      return result['is_new_user'] == true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await prefs.clear();
    _user = null;
    notifyListeners();
  }
}
