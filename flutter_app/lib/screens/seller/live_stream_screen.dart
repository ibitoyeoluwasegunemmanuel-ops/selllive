// lib/screens/seller/live_stream_screen.dart
// The seller's view WHILE streaming — camera feed + product pins + order alerts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final String dailyRoomUrl;
  final String title;

  const LiveStreamScreen({
    required this.streamId,
    required this.dailyRoomUrl,
    required this.title,
    super.key,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _chatMessages = [];
  Map<String, dynamic>? _pinnedProduct;
  int _viewerCount = 0;
  int _orderCount = 0;
  bool _isMuted = false;
  bool _isCameraOff = false;
  Duration _streamDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _subscribeToOrders();
    _subscribeToChat();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _streamDuration += const Duration(seconds: 1));
      return true;
    });
  }

  void _subscribeToOrders() {
    _channel = _supabase
        .channel('orders:${widget.streamId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: widget.streamId,
          ),
          callback: (payload) {
            final order = payload.newRecord;
            setState(() {
              _recentOrders.insert(0, order);
              if (_recentOrders.length > 5) _recentOrders.removeLast();
              _orderCount++;
            });
            _showOrderAlert(order);
          },
        )
        .subscribe();
  }

  void _subscribeToChat() {
    _supabase
        .channel('chat:${widget.streamId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: widget.streamId,
          ),
          callback: (payload) {
            setState(() {
              _chatMessages.insert(0, payload.newRecord);
              if (_chatMessages.length > 20) _chatMessages.removeLast();
            });
          },
        )
        .subscribe();
  }

  void _showOrderAlert(Map<String, dynamic> order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shopping_bag, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'New order! ₦${((order['total_amount'] as int? ?? 0) / 100).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: SellLiveTheme.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _endStream() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SellLiveTheme.bgCard,
        title: const Text('End stream?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You had $_orderCount orders and $_viewerCount viewers.',
          style: const TextStyle(color: SellLiveTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Going'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: SellLiveTheme.error),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<ApiService>().endStream(widget.streamId);
      if (mounted) context.go('/seller/dashboard');
    }
  }

  String get _formattedDuration {
    final h = _streamDuration.inHours;
    final m = _streamDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _streamDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==========================
          // VIDEO FEED (Daily.co)
          // Replace this container with DailyWidget when integrating:
          // daily_flutter: DailyWidget(roomUrl: widget.dailyRoomUrl)
          // ==========================
          Container(
            color: const Color(0xFF0D0500),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Color(0xFF444444), size: 80),
                  SizedBox(height: 12),
                  Text('Your camera feed appears here',
                      style: TextStyle(color: Color(0xFF444444))),
                  SizedBox(height: 8),
                  Text('daily_flutter: DailyWidget(roomUrl: ...)',
                      style: TextStyle(color: Color(0xFF333333), fontSize: 11,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ),

          // ==========================
          // TOP BAR
          // ==========================
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: SellLiveTheme.liveRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          const Text('LIVE', style: TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_formattedDuration,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    // Viewer count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined,
                              color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Text('$_viewerCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Orders count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: SellLiveTheme.success.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_bag, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text('$_orderCount orders',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==========================
          // BOTTOM CONTROLS
          // ==========================
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recent orders ticker
                  if (_recentOrders.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: SellLiveTheme.success.withOpacity(0.15),
                        border: Border.all(color: SellLiveTheme.success.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_bag,
                              color: SellLiveTheme.success, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'New order: ₦${((_recentOrders.first['total_amount'] as int? ?? 0) / 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: SellLiveTheme.success,
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),

                  // Chat preview
                  if (_chatMessages.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _chatMessages.take(3).map((msg) {
                          final isBuy = msg['is_buy_cmd'] == true;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '@viewer  ',
                                    style: TextStyle(
                                      color: isBuy
                                          ? SellLiveTheme.success
                                          : SellLiveTheme.primaryOrange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg['message'],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Control buttons
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _controlBtn(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          color: _isMuted ? SellLiveTheme.error : Colors.white,
                          onTap: () => setState(() => _isMuted = !_isMuted),
                        ),
                        _controlBtn(
                          icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                          label: _isCameraOff ? 'Camera On' : 'Camera',
                          color: _isCameraOff ? SellLiveTheme.error : Colors.white,
                          onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                        ),
                        _controlBtn(
                          icon: Icons.flip_camera_android,
                          label: 'Flip',
                          color: Colors.white,
                          onTap: () {},
                        ),
                        _controlBtn(
                          icon: Icons.sell,
                          label: 'Products',
                          color: SellLiveTheme.primaryOrange,
                          onTap: () => _showProductSheet(),
                        ),
                        // END STREAM
                        GestureDetector(
                          onTap: _endStream,
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: SellLiveTheme.liveRed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.stop, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  void _showProductSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductPinSheet(streamId: widget.streamId),
    );
  }
}

// ============================================================
// PRODUCT PIN SHEET
// ============================================================
class _ProductPinSheet extends StatefulWidget {
  final String streamId;
  const _ProductPinSheet({required this.streamId});

  @override
  State<_ProductPinSheet> createState() => _ProductPinSheetState();
}

class _ProductPinSheetState extends State<_ProductPinSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '10');
  bool _isSaving = false;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text);
    if (name.isEmpty || price == null) return;

    setState(() => _isSaving = true);
    try {
      await context.read<ApiService>().pinProduct(
        streamId: widget.streamId,
        name: name,
        price: price,
        position: 1,
        stock: int.tryParse(_stockCtrl.text) ?? 10,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pin a Product',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Product name'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Price (₦)'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Stock'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Pin Product to Stream'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
