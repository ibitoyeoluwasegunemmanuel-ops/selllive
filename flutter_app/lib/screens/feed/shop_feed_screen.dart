// lib/screens/feed/shop_feed_screen.dart
// TikTok/Instagram-style scrollable product feed
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class ShopFeedScreen extends StatefulWidget {
  const ShopFeedScreen({super.key});
  @override State<ShopFeedScreen> createState() => _ShopFeedScreenState();
}

class _ShopFeedScreenState extends State<ShopFeedScreen> {
  final PageController _pageController = PageController();
  List<dynamic> _posts = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadPosts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) { _currentPage = 1; _hasMore = true; }
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().getFeedPosts(page: _currentPage);
      setState(() {
        if (refresh) {
          _posts = data;
        } else {
          _posts.addAll(data);
        }
        _hasMore = data.length >= 10;
        _currentPage++;
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(text: 'Shop', style: TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
              TextSpan(text: 'Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            onPressed: () => context.push('/create-post'),
          ),
        ],
      ),
      body: _isLoading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : _posts.isEmpty
              ? _buildEmpty()
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _posts.length + (_hasMore ? 1 : 0),
                  onPageChanged: (index) {
                    // Load more when near end
                    if (index >= _posts.length - 2 && _hasMore && !_isLoading) {
                      _loadPosts();
                    }
                    // Track view
                    if (index < _posts.length) {
                      context.read<ApiService>().trackPostView(_posts[index]['id']);
                    }
                  },
                  itemBuilder: (context, index) {
                    if (index >= _posts.length) {
                      return const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange));
                    }
                    return _PostCard(
                      post: _posts[index],
                      onLike: () => _toggleLike(index),
                      onComment: () => _showComments(_posts[index]['id']),
                      onBuy: (productId) => _buy(_posts[index]['id'], productId),
                      onShare: () => _share(_posts[index]['id']),
                      onSellerTap: () => context.push('/stream/${_posts[index]['seller']?['id']}'),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.photo_camera_outlined, color: SellLiveTheme.textHint, size: 64),
        const SizedBox(height: 16),
        const Text('No posts yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Follow sellers to see their products here', style: TextStyle(color: SellLiveTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: () => _loadPosts(refresh: true), child: const Text('Refresh')),
      ],
    ),
  );

  Future<void> _toggleLike(int index) async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) { context.push('/auth/phone'); return; }
    try {
      final result = await context.read<ApiService>().likePost(_posts[index]['id']);
      setState(() {
        final liked = result['liked'] == true;
        _posts[index]['liked'] = liked;
        _posts[index]['like_count'] = (_posts[index]['like_count'] ?? 0) + (liked ? 1 : -1);
      });
    } catch (_) {}
  }

  void _showComments(String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommentsSheet(postId: postId),
    );
  }

  Future<void> _buy(String postId, String productId) async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) { context.push('/auth/phone'); return; }

    final post = _posts.firstWhere((p) => p['id'] == postId, orElse: () => null);
    final products = (post?['products'] as List? ?? []);
    final product = products.firstWhere((p) => p['id'] == productId, orElse: () => null);
    if (product == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PostBuySheet(
        postId: postId,
        product: product,
        onBuy: (qty, address, phone) async {
          try {
            final result = await context.read<ApiService>().buyFromPost(
              postId: postId,
              productId: productId,
              quantity: qty,
              deliveryAddress: address,
              deliveryPhone: phone,
            );
            final url = result['payment_url'];
            if (url != null && await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _share(String postId) async {
    try {
      final result = await context.read<ApiService>().sharePost(postId);
      final url = result['whatsapp_url'];
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}

// ============================================================
// INDIVIDUAL POST CARD — full screen
// ============================================================
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final Function(String) onBuy;
  final VoidCallback onShare;
  final VoidCallback onSellerTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onBuy,
    required this.onShare,
    required this.onSellerTap,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() { _heartController.dispose(); super.dispose(); }

  void _doubleTapLike() {
    widget.onLike();
    setState(() => _showHeart = true);
    _heartController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showHeart = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final seller = widget.post['seller'] ?? {};
    final profile = widget.post['seller_profile'] ?? {};
    final products = (widget.post['products'] as List? ?? []);
    final isLiked = widget.post['liked'] == true;

    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── MEDIA BACKGROUND ────────────────────────────────
          widget.post['media_type'] == 'video'
              ? _VideoBackground(
                  videoUrl: widget.post['media_url'],
                  thumbnailUrl: widget.post['thumbnail_url'],
                )
              : CachedNetworkImage(
                  imageUrl: widget.post['media_url'],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF0D0D0D)),
                ),

          // ── GRADIENT OVERLAYS ────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.85)],
                stops: const [0, 0.2, 0.6, 1.0],
              ),
            ),
          ),

          // ── DOUBLE TAP HEART ────────────────────────────────
          if (_showHeart)
            Center(
              child: AnimatedBuilder(
                animation: _heartController,
                builder: (_, __) => Opacity(
                  opacity: (1 - _heartController.value).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + _heartController.value * 1.5,
                    child: const Icon(Icons.favorite, color: Colors.white, size: 120),
                  ),
                ),
              ),
            ),

          // ── RIGHT SIDE ACTIONS ───────────────────────────────
          Positioned(
            right: 12,
            bottom: products.isNotEmpty ? 200 : 100,
            child: Column(
              children: [
                // Seller avatar
                GestureDetector(
                  onTap: widget.onSellerTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: SellLiveTheme.primaryOrange,
                        backgroundImage: seller['avatar_url'] != null
                            ? CachedNetworkImageProvider(seller['avatar_url']) : null,
                        child: seller['avatar_url'] == null
                            ? Text((seller['name'] ?? 'S')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                            : null,
                      ),
                      Positioned(
                        bottom: -4, left: 0, right: 0,
                        child: Center(
                          child: Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(color: SellLiveTheme.primaryOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Like button
                _ActionBtn(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.white,
                  label: _fmtCount(widget.post['like_count'] ?? 0),
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 16),

                // Comment button
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.white,
                  label: _fmtCount(widget.post['comment_count'] ?? 0),
                  onTap: widget.onComment,
                ),
                const SizedBox(height: 16),

                // Share / WhatsApp
                _ActionBtn(
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: _fmtCount(widget.post['share_count'] ?? 0),
                  onTap: widget.onShare,
                ),
                const SizedBox(height: 16),

                // Views
                _ActionBtn(
                  icon: Icons.visibility_outlined,
                  color: Colors.white,
                  label: _fmtCount(widget.post['view_count'] ?? 0),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // ── BOTTOM: SELLER INFO + CAPTION + PRODUCTS ─────────
          Positioned(
            bottom: 0, left: 0, right: 72,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seller name + verified badge
                  GestureDetector(
                    onTap: widget.onSellerTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@${profile['business_name'] ?? seller['name'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (profile['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: SellLiveTheme.primaryOrange, size: 16),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Caption
                  if (widget.post['caption'] != null)
                    Text(
                      widget.post['caption'],
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),

                  // Tagged products horizontal scroll
                  if (products.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _ProductChip(
                          product: products[i],
                          onTap: () => widget.onBuy(products[i]['id']),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Icon(icon, color: color, size: 28, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
      ],
    ),
  );
}

class _ProductChip extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductChip({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priceNaira = (product['price'] as int? ?? 0) / 100;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SellLiveTheme.primaryOrange.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            if (product['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(imageUrl: product['image_url'], width: 36, height: 36, fit: BoxFit.cover),
              )
            else
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF2A1A0A), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.shopping_bag, color: SellLiveTheme.primaryOrange, size: 18),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(product['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('₦${priceNaira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoBackground extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  const _VideoBackground({required this.videoUrl, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    // In production: use video_player package
    // VideoPlayerController.networkUrl(Uri.parse(videoUrl))
    return thumbnailUrl != null
        ? CachedNetworkImage(imageUrl: thumbnailUrl!, fit: BoxFit.cover)
        : Container(
            color: const Color(0xFF0D0500),
            child: const Center(child: Icon(Icons.play_circle_outline, color: Color(0xFF333333), size: 80)),
          );
  }
}

// ============================================================
// COMMENTS SHEET
// ============================================================
class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({required this.postId, super.key});
  @override State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<dynamic> _comments = [];
  final _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await context.read<ApiService>().getPostComments(widget.postId);
    setState(() { _comments = data; _isLoading = false; });
  }

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final result = await context.read<ApiService>().addPostComment(widget.postId, text);
      _commentController.clear();
      setState(() => _comments.add(result['comment']));
    } catch (_) {}
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('${_comments.length} comments', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: SellLiveTheme.textHint), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet. Be first!', style: TextStyle(color: SellLiveTheme.textHint)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final user = c['user'] ?? {};
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: SellLiveTheme.primaryOrange,
                                  backgroundImage: user['avatar_url'] != null ? CachedNetworkImageProvider(user['avatar_url']) : null,
                                  child: user['avatar_url'] == null ? Text((user['name'] ?? '?')[0], style: const TextStyle(color: Colors.white, fontSize: 11)) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user['name'] ?? '', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w700, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(c['comment'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Comment input
          SafeArea(
            child: Container(
              padding: EdgeInsets.only(left: 16, right: 12, top: 10, bottom: 10 + MediaQuery.of(context).viewInsets.bottom),
              color: const Color(0xFF1A1A1A),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: SellLiveTheme.textHint, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _send,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: SellLiveTheme.primaryOrange, shape: BoxShape.circle),
                      child: _isSending
                          ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white, size: 18),
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
}

// ============================================================
// BUY SHEET FOR POST PRODUCTS
// ============================================================
class PostBuySheet extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> product;
  final Function(int, String, String) onBuy;
  const PostBuySheet({required this.postId, required this.product, required this.onBuy, super.key});
  @override State<PostBuySheet> createState() => _PostBuySheetState();
}

class _PostBuySheetState extends State<PostBuySheet> {
  int _qty = 1;
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  double get _total => ((widget.product['price'] as int? ?? 0) * _qty) / 100;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.product['image_url'] != null)
                ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(imageUrl: widget.product['image_url'], width: 60, height: 60, fit: BoxFit.cover))
              else
                Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFF2A1A0A), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.shopping_bag, color: SellLiveTheme.primaryOrange)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.product['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('₦${_total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              )),
              Row(children: [
                GestureDetector(
                  onTap: () { if (_qty > 1) setState(() => _qty--); },
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.remove, color: Colors.white, size: 16)),
                ),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$_qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                GestureDetector(
                  onTap: () => setState(() => _qty++),
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add, color: Colors.white, size: 16)),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _addressCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined, color: SellLiveTheme.textHint))),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Phone for delivery', prefixIcon: Icon(Icons.phone, color: SellLiveTheme.textHint))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); widget.onBuy(_qty, _addressCtrl.text, _phoneCtrl.text); },
              child: Text('Pay ₦${_total.toStringAsFixed(0)} with Flutterwave'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
