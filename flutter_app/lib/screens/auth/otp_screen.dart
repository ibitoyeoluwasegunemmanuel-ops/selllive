// lib/screens/auth/otp_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class OtpScreen extends StatefulWidget {
  final Map<String, dynamic> data; // {phone, role}
  const OtpScreen({required this.data, super.key});

  // For router compatibility
  factory OtpScreen.fromPhone(String phone) =>
      OtpScreen(data: {'phone': phone, 'role': 'buyer'});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  int _resendCountdown = 30;
  Timer? _timer;

  String get phone => widget.data['phone'] as String;
  String get role => widget.data['role'] as String? ?? 'buyer';

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startCountdown() {
    _resendCountdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  String get _otpCode =>
      _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpCode.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final isNewUser = await context.read<AuthService>().verifyOTP(
        phone: phone,
        code: _otpCode,
        role: role,
      );

      if (!mounted) return;

      if (isNewUser) {
        // New user — go to register screen to collect name
        context.go('/auth/register', extra: {'phone': phone, 'role': role});
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Wrong code. Check your SMS and try again.');
      // Clear inputs
      for (var c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == 5) {
      _focusNodes[index].unfocus();
      _verify();
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SellLiveTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text('Enter verification\ncode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a 6-digit code to\n$phone',
              style: const TextStyle(
                  color: SellLiveTheme.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 40),

            // OTP input boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpBox(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                onChanged: (v) => _onDigitEntered(i, v),
                onBackspace: () => _onBackspace(i),
                hasError: _error != null,
              )),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(
                      color: SellLiveTheme.error, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            // Resend
            Row(
              children: [
                const Text("Didn't get it? ",
                    style: TextStyle(color: SellLiveTheme.textSecondary)),
                if (_resendCountdown > 0)
                  Text('Resend in ${_resendCountdown}s',
                      style: const TextStyle(color: SellLiveTheme.textHint))
                else
                  GestureDetector(
                    onTap: () {
                      context.read<AuthService>().sendOTP(phone);
                      _startCountdown();
                    },
                    child: const Text('Resend code',
                        style: TextStyle(
                            color: SellLiveTheme.primaryOrange,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Verify & Continue'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback onBackspace;
  final bool hasError;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: SellLiveTheme.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? SellLiveTheme.error
                    : const Color(0xFF333333),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? SellLiveTheme.error
                    : SellLiveTheme.primaryOrange,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
