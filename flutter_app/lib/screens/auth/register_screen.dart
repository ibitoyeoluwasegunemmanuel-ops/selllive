// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic> data; // {phone, role, code}
  const RegisterScreen({required this.data, super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get isSeller => widget.data['role'] == 'seller';

  Future<void> _register() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter your full name');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await context.read<AuthService>().verifyOTP(
        phone: widget.data['phone'],
        code: widget.data['code'] ?? '',
        name: name,
        role: widget.data['role'] ?? 'buyer',
      );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(backgroundColor: SellLiveTheme.bgDark),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSeller ? 'Set up your\nseller account' : 'What\'s your\nname?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSeller
                  ? 'This is what buyers will see on your profile'
                  : 'This is how sellers will know you',
              style: const TextStyle(
                  color: SellLiveTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: isSeller ? 'Your full name' : 'Your name',
                prefixIcon: const Icon(Icons.person_outline,
                    color: SellLiveTheme.textHint),
              ),
            ),

            if (isSeller) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _businessNameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Business / shop name (e.g. Ada\'s Ankara)',
                  prefixIcon: Icon(Icons.storefront,
                      color: SellLiveTheme.textHint),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SellLiveTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: SellLiveTheme.primaryOrange.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: SellLiveTheme.primaryOrange, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'ll add your bank account details after signing up to receive payments.',
                        style: TextStyle(
                            color: SellLiveTheme.textSecondary, fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(
                      color: SellLiveTheme.error, fontSize: 13)),
            ],

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(isSeller ? 'Create Seller Account' : 'Get Started'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
