// lib/screens/stream/watch_stream_screen.dart
// Full live stream viewer — video + real-time chat + BUY command
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class WatchStreamScreen extends StatefulWidget {
  final String streamId;
  const WatchStreamScreen({required this.streamId, super.key});

  @override
  State<WatchStreamScreen> createState() => _WatchStreamScreenState();
}

class _WatchStreamScreenState extends State<WatchStreamScreen> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _stream;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isBuying = false;
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _loadStream();
    _subscribeToChat();
  }

  Future<void> _loadStream() async {
    try {
      final stream = await context.read<ApiService>().getStream(widget.streamId);
      setState(() { _stream = stream; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToChat() {
    // Real-time chat via Supabase Realtime
    _chatChannel = _supabase
        .channel('stream:${widget.streamId}')
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
            final newMsg = payload.newRecord;
            setState(() => _messages.add(newMsg));
            _scrollToBottom();
          },
        )
        .subscribe();

    // Load recent chat history
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final response = await _supabase
        .from('chat_messages')
        .select('*, user:users!user_id(name)')
        .eq('stream_id', widget.streamId)
        .order('created_at', ascending: true)
        .limit(50);

    setState(() => _messages = List<Map<String, dynamic>>.from(response));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _stream == null) return;

    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      context.push('/auth/phone');
      return;
    }

    _chatController.clear();

    // Insert into Supabase — Realtime will broadcast to all viewers
    await _supabase.from('chat_messages').insert({
      'stream_id': widget.streamId,
      'user_id': auth.user!['id'],
      'message': text,
      'is_buy_cmd': text.toUpperCase().startsWith('BUY'),
    });

    // If it's a BUY command, trigger payment flow
    if (text.toUpperCase().startsWith('BUY')) {
      _handleBuyCommand(text);
    }
  }

  void _handleBuyCommand(String text) {
    // Parse quantity from "BUY 2" or just "BUY"
    final parts = text.split(' ');
    final quantity = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;

    // Find active pinned product
    final products = (_stream?['products'] as List?)
        ?.where((p) => p['is_active'] == true)
        .toList();

    if (products == null || products.isEmpty) {
      _showSnack('No product is pinned right now');
      return;
    }

    final product = products[0]; // buy the first active product
    _showBuySheet(product, quantity);
  }

  void _showBuySheet(Map<String, dynamic> product, int quantity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BuySheet(
        product: product,
        initialQuantity: quantity,
        streamId: widget.streamId,
        onBuy: (productId, qty, address, phone) =>
            _initiatePurchase(productId, qty, address, phone),
      ),
    );
  }

  Future<void> _initiatePurchase(
      String productId, int qty, String address, String phone) async {
    setState(() => _isBuying = true);
    try {
      final result = await context.read<ApiService>().initiatePayment(
        productId: productId,
        streamId: widget.streamId,
        quantity: qty,
        deliveryAddress: address,
        deliveryPhone: phone,
      );

      // Open Flutterwave payment page
      final paymentUrl = result['payment_url'];
      if (paymentUrl != null && await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showSnack('Could not create order. Please try again.');
    } finally {
      setState(() => _isBuying = false);
    }
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      context.push('/auth/phone');
      return;
    }
    try {
      final result = await context.read<ApiService>()
          .toggleFollow(_stream!['seller']['id']);
      setState(() => _isFollowing = result['following'] == true);
    } catch (_) {}
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: SellLiveTheme.bgCard));
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SellLiveTheme.bgDark,
        body: Center(
            child: CircularProgressIndicator(
                color: SellLiveTheme.primaryOrange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video area (placeholder — Daily.co WebRTC goes here)
          _buildVideoArea(),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(),

                const Spacer(),

                // Pinned product
                if (_stream?['products'] != null)
                  ...[_buildPinnedProduct(), const SizedBox(height: 8)],

                // Chat messages
                _buildChatArea(),

                // Chat input
                _buildChatInput(),
              ],
            ),
          ),

          if (_isBuying)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                    color: SellLiveTheme.primaryOrange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    // In production: replace with Daily.co widget
    // daily_flutter package: DailyWidget(roomUrl: stream['daily_room_url'])
    return Container(
      color: const Color(0xFF0D0500),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv, color: Color(0xFF333333), size: 80),
            SizedBox(height: 12),
            Text('Live video stream', style: TextStyle(color: Color(0xFF333333))),
          ],
        ),
      ),
    );
    // TODO: Replace with:
    // return DailyWidget(roomUrl: _stream?['daily_room_url'] ?? '');
  }

  Widget _buildTopBar() {
    final seller = _stream?['seller'] ?? {};
    final profile = _stream?['seller_profile'] ?? {};

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 10),

          // Seller info
          CircleAvatar(
            radius: 16,
            backgroundColor: SellLiveTheme.primaryOrange,
            backgroundImage: seller['avatar_url'] != null
                ? CachedNetworkImageProvider(seller['avatar_url']) : null,
            child: seller['avatar_url'] == null
                ? Text(
                    (seller['name'] ?? 'S')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile['business_name'] ?? seller['name'] ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
                Text('${profile['followers_count'] ?? 0} followers · ★ ${profile['trust_score'] ?? 5.0}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),

          // Follow button
          GestureDetector(
            onTap: _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _isFollowing ? Colors.transparent : SellLiveTheme.primaryOrange,
                border: Border.all(color: SellLiveTheme.primaryOrange),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isFollowing ? 'Following' : '+ Follow',
                style: TextStyle(
                  color: _isFollowing ? SellLiveTheme.primaryOrange : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Viewer count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye_outlined,
                    color: Colors.white70, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${_stream?['viewer_count'] ?? 0}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedProduct() {
    final products = (_stream?['products'] as List?)
        ?.where((p) => p['is_active'] == true)
        .toList();
    if (products == null || products.isEmpty) return const SizedBox.shrink();

    final product = products[0];
    final priceNaira = (product['price'] as int) / 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => _showBuySheet(product, 1),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SellLiveTheme.primaryOrange, width: 1),
          ),
          child: Row(
            children: [
              // Product image
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1A0A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                            imageUrl: product['image_url'], fit: BoxFit.cover),
                      )
                    : const Icon(Icons.shopping_bag,
                        color: SellLiveTheme.primaryOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['name'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(
                      '₦${priceNaira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(
                          color: SellLiveTheme.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: SellLiveTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('BUY NOW',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final msg = _messages[i];
          final isBuy = msg['is_buy_cmd'] == true;
          final userName = (msg['user'] as Map?)?['name'] ?? 'User';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '@$userName  ',
                    style: TextStyle(
                      color: isBuy
                          ? SellLiveTheme.success
                          : SellLiveTheme.primaryOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: msg['message'],
                    style: TextStyle(
                      color: isBuy ? SellLiveTheme.success : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  if (isBuy)
                    const TextSpan(
                      text: '  ✓ order created',
                      style: TextStyle(
                          color: SellLiveTheme.success,
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatInput() {
    final auth = context.watch<AuthService>();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      color: Colors.black54,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: auth.isLoggedIn
                    ? 'Type BUY to order...'
                    : 'Log in to chat',
                hintStyle: const TextStyle(
                    color: SellLiveTheme.textHint, fontSize: 13),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: auth.isLoggedIn,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: SellLiveTheme.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BUY BOTTOM SHEET
// ============================================================
class _BuySheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final int initialQuantity;
  final String streamId;
  final Function(String, int, String, String) onBuy;

  const _BuySheet({
    required this.product,
    required this.initialQuantity,
    required this.streamId,
    required this.onBuy,
  });

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  late int _qty;
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQuantity;
  }

  double get _totalNaira =>
      ((widget.product['price'] as int) * _qty) / 100;

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
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1A0A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: widget.product['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                            imageUrl: widget.product['image_url'],
                            fit: BoxFit.cover),
                      )
                    : const Icon(Icons.shopping_bag,
                        color: SellLiveTheme.primaryOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product['name'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '₦${(_totalNaira).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(
                          color: SellLiveTheme.primaryOrange,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                  ],
                ),
              ),
              // Quantity selector
              Row(
                children: [
                  _qtyBtn(Icons.remove, () {
                    if (_qty > 1) setState(() => _qty--);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$_qty',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ),
                  _qtyBtn(Icons.add, () => setState(() => _qty++)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _addressController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Delivery address',
              prefixIcon:
                  Icon(Icons.location_on_outlined, color: SellLiveTheme.textHint),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Phone for delivery',
              prefixIcon: Icon(Icons.phone, color: SellLiveTheme.textHint),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.pop();
                widget.onBuy(
                  widget.product['id'],
                  _qty,
                  _addressController.text,
                  _phoneController.text,
                );
              },
              child: Text(
                'Pay ₦${_totalNaira.toStringAsFixed(0)} with Flutterwave',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: SellLiveTheme.bgCardElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
