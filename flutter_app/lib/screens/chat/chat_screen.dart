// lib/screens/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

// ============================================================
// CHAT LIST SCREEN
// ============================================================
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().getConversations();
      setState(() => _conversations = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : _conversations.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: SellLiveTheme.primaryOrange,
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF1A1A1A), height: 1),
                    itemBuilder: (_, i) => _ConversationTile(
                      conv: _conversations[i],
                      onTap: () => context.push('/chat/${_conversations[i]['id']}', extra: _conversations[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.chat_bubble_outline, color: SellLiveTheme.textHint, size: 64),
        const SizedBox(height: 16),
        const Text('No messages yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Chat with sellers after watching their streams', style: TextStyle(color: SellLiveTheme.textSecondary), textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conv;
  final VoidCallback onTap;
  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final other = conv['other_user'] ?? {};
    final unread = (conv['unread_count'] as int? ?? 0);
    final lastMsg = conv['last_message'] ?? '';
    final lastTime = conv['last_message_at'];

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: SellLiveTheme.primaryOrange,
            backgroundImage: other['avatar_url'] != null ? CachedNetworkImageProvider(other['avatar_url']) : null,
            child: other['avatar_url'] == null
                ? Text((other['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          if (unread > 0)
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(color: SellLiveTheme.primaryOrange, shape: BoxShape.circle),
                child: Center(child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              ),
            ),
        ],
      ),
      title: Text(other['name'] ?? '', style: TextStyle(color: Colors.white, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: unread > 0 ? SellLiveTheme.primaryOrange : SellLiveTheme.textHint, fontSize: 12,
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400)),
      trailing: lastTime != null ? Text(
        timeago.format(DateTime.parse(lastTime), locale: 'en_short'),
        style: TextStyle(color: unread > 0 ? SellLiveTheme.primaryOrange : SellLiveTheme.textHint, fontSize: 11),
      ) : null,
    );
  }
}

// ============================================================
// CONVERSATION SCREEN (actual chat)
// ============================================================
class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? initialData;
  const ConversationScreen({required this.conversationId, this.initialData, super.key});
  @override State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  List<dynamic> _messages = [];
  RealtimeChannel? _channel;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().getMessages(widget.conversationId);
      setState(() => _messages = data);
      _scrollToBottom();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _subscribeToMessages() {
    _channel = _supabase
        .channel('chat:${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.conversationId),
          callback: (payload) {
            final msg = payload.newRecord;
            final userId = context.read<AuthService>().user?['id'];
            if (msg['sender_id'] != userId) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    _messageController.clear();
    setState(() => _isSending = true);

    final userId = context.read<AuthService>().user?['id'];
    final optimistic = {'id': 'temp', 'content': text, 'sender_id': userId, 'message_type': 'text', 'created_at': DateTime.now().toIso8601String(), 'sender': context.read<AuthService>().user};
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final result = await context.read<ApiService>().sendMessage(conversationId: widget.conversationId, content: text);
      setState(() {
        _messages.removeLast();
        _messages.add(result);
      });
    } catch (_) {
      setState(() => _messages.removeLast());
    }
    setState(() => _isSending = false);
  }

  void _startCall(String type) async {
    try {
      final result = await context.read<ApiService>().initiateCall(
        conversationId: widget.conversationId,
        callType: type,
      );
      if (mounted) {
        context.push('/call/${result['call_id']}', extra: result);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.initialData?['other_user'] ?? {};
    final userId = context.read<AuthService>().user?['id'];

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: SellLiveTheme.primaryOrange,
              backgroundImage: other['avatar_url'] != null ? CachedNetworkImageProvider(other['avatar_url']) : null,
              child: other['avatar_url'] == null ? Text((other['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)) : null,
            ),
            const SizedBox(width: 10),
            Text(other['name'] ?? 'Chat', style: const TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: SellLiveTheme.primaryOrange),
            onPressed: () => _startCall('voice'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: SellLiveTheme.primaryOrange),
            onPressed: () => _startCall('video'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_id'] == userId;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0xFF111111),
      border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
    ),
    child: SafeArea(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: SellLiveTheme.textHint, fontSize: 13),
                filled: true,
                fillColor: SellLiveTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: SellLiveTheme.primaryOrange, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final type = message['message_type'] ?? 'text';

    if (type == 'call_started' || type == 'call_ended') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(20)),
          child: Text(message['content'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
        ),
      );
    }

    if (type == 'product_card') {
      final product = message['product_data'] as Map?;
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: 220,
          decoration: BoxDecoration(
            color: isMe ? SellLiveTheme.primaryOrange.withOpacity(0.15) : SellLiveTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SellLiveTheme.primaryOrange.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product?['image_url'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: CachedNetworkImage(imageUrl: product!['image_url'], height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product?['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('₦${((product?['price'] as num? ?? 0) / 100).toStringAsFixed(0)}',
                        style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                        child: const Text('Buy Now', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? SellLiveTheme.primaryOrange : SellLiveTheme.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Text(
          message['content'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : SellLiveTheme.textPrimary, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}
