// lib/screens/auth/phone_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phoneController = TextEditingController(text: '+234');
  bool _isSeller = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid Nigerian phone number');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await context.read<AuthService>().sendOTP(phone);
      if (mounted) {
        context.push('/auth/otp', extra: {
          'phone': phone,
          'role': _isSeller ? 'seller' : 'buyer',
        });
      }
    } catch (e) {
      setState(() => _error = 'Could not send OTP. Check your number and try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: SellLiveTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.live_tv, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 32),
              const Text('Welcome to\nSellLive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Enter your phone number to get started',
                  style: TextStyle(color: SellLiveTheme.textSecondary, fontSize: 15)),
              const SizedBox(height: 40),

              // Phone input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '+234 800 000 0000',
                  prefixIcon: Icon(Icons.phone, color: SellLiveTheme.textHint),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: SellLiveTheme.error, fontSize: 13)),
              ],

              const SizedBox(height: 24),

              // Seller toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SellLiveTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSeller
                        ? SellLiveTheme.primaryOrange
                        : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: SellLiveTheme.primaryOrange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('I want to sell',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                          Text('Register as a seller',
                              style: TextStyle(
                                  color: SellLiveTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isSeller,
                      onChanged: (v) => setState(() => _isSeller = v),
                      activeColor: SellLiveTheme.primaryOrange,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Send Verification Code'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'We\'ll send a 6-digit code to verify your number',
                  style: const TextStyle(
                      color: SellLiveTheme.textHint, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
