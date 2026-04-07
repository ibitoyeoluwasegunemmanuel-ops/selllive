// lib/screens/chat/call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final Map<String, dynamic> callData;
  const CallScreen({required this.callId, required this.callData, super.key});
  @override State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOff = false;
  bool _callConnected = false;
  Duration _callDuration = Duration.zero;
  Timer? _timer;
  String _status = 'Calling...';

  bool get isVideo => widget.callData['call_type'] == 'video';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Simulate connection after 2 seconds (Daily.co connects here)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _onCallConnected();
    });
  }

  void _onCallConnected() {
    setState(() { _callConnected = true; _status = 'Connected'; });
    context.read<ApiService>().updateCallStatus(widget.callId, 'active');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    await context.read<ApiService>().updateCallStatus(widget.callId, 'ended');
    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      context.pop();
    }
  }

  String get _formattedDuration {
    final m = _callDuration.inMinutes.toString().padLeft(2, '0');
    final s = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receiverName = widget.callData['receiver_name'] ?? 'Seller';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video background (Daily.co widget goes here)
          if (isVideo && !_isCameraOff)
            Container(
              color: const Color(0xFF0D0500),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Color(0xFF333333), size: 80),
                    SizedBox(height: 12),
                    Text('Video call\nIntegrate daily_flutter here', style: TextStyle(color: Color(0xFF444444), textAlign: TextAlign.center)),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0A00), Color(0xFF0D0500)],
                ),
              ),
            ),

          // Call UI overlay
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Avatar
                CircleAvatar(
                  radius: 48,
                  backgroundColor: SellLiveTheme.primaryOrange,
                  child: Text(
                    receiverName.isNotEmpty ? receiverName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                Text(receiverName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _callConnected ? _formattedDuration : _status,
                  style: TextStyle(color: _callConnected ? SellLiveTheme.success : SellLiveTheme.textSecondary, fontSize: 16),
                ),
                const Spacer(),

                // Control buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CallBtn(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            label: _isMuted ? 'Unmute' : 'Mute',
                            color: _isMuted ? SellLiveTheme.error : Colors.white,
                            bgColor: const Color(0xFF2A2A2A),
                            onTap: () => setState(() => _isMuted = !_isMuted),
                          ),
                          // END CALL
                          _CallBtn(
                            icon: Icons.call_end,
                            label: 'End',
                            color: Colors.white,
                            bgColor: SellLiveTheme.error,
                            size: 72,
                            onTap: _endCall,
                          ),
                          _CallBtn(
                            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                            label: 'Speaker',
                            color: _isSpeakerOn ? SellLiveTheme.primaryOrange : Colors.white,
                            bgColor: const Color(0xFF2A2A2A),
                            onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                          ),
                        ],
                      ),
                      if (isVideo) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallBtn(
                              icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                              label: _isCameraOff ? 'Cam Off' : 'Camera',
                              color: _isCameraOff ? SellLiveTheme.error : Colors.white,
                              bgColor: const Color(0xFF2A2A2A),
                              onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                            ),
                            _CallBtn(
                              icon: Icons.flip_camera_android,
                              label: 'Flip',
                              color: Colors.white,
                              bgColor: const Color(0xFF2A2A2A),
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final double size;

  const _CallBtn({
    required this.icon, required this.label, required this.color,
    required this.bgColor, required this.onTap, this.size = 56,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: size * 0.42),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    ),
  );
}
