// lib/screens/seller_profile/seller_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  const SellerProfileScreen({required this.sellerId, super.key});
  @override State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String,dynamic>? _profile;
  List<dynamic> _posts    = [];
  List<dynamic> _reviews  = [];
  bool _isLoading  = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        context.read<ApiService>().getSellerProfile(widget.sellerId),
        context.read<ApiService>().getSellerPosts(widget.sellerId),
        context.read<ApiService>().getSellerReviews(widget.sellerId),
      ]);
      setState(() {
        _profile  = results[0] as Map<String,dynamic>?;
        _posts    = results[1] as List<dynamic>;
        _reviews  = results[2] as List<dynamic>;
        _isFollowing = _profile?['is_following'] == true;
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);
    try {
      final result = await context.read<ApiService>().followSeller(widget.sellerId);
      setState(() => _isFollowing = result['following'] == true);
    } catch (_) {}
    setState(() => _isFollowLoading = false);
  }

  Future<void> _openChat() async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) { context.push('/auth/phone'); return; }
    try {
      final conv = await context.read<ApiService>().startConversation(widget.sellerId);
      if (mounted) context.push('/chat/${conv['id']}', extra: {'other_user': _profile?['user']});
    } catch (_) {}
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      body: Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange)),
    );

    final user    = _profile?['user']    as Map? ?? {};
    final profile = _profile?['profile'] as Map? ?? {};
    final avgRating   = (profile['avg_rating'] as num?)?.toDouble() ?? 5.0;
    final reviewCount = profile['review_count'] as int? ?? 0;
    final followers   = profile['followers_count'] as int? ?? 0;

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: SellLiveTheme.bgDark,
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image / gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A0800), Color(0xFF0D0D0D)],
                      ),
                    ),
                  ),
                  // Profile info
                  Positioned(
                    bottom: 16, left: 20, right: 20,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: SellLiveTheme.primaryOrange,
                          backgroundImage: user['avatar_url'] != null
                              ? CachedNetworkImageProvider(user['avatar_url']) : null,
                          child: user['avatar_url'] == null
                              ? Text((user['name'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(profile['business_name'] ?? user['name'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                if (profile['is_verified'] == true) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: SellLiveTheme.primaryOrange, size: 18),
                                ],
                              ]),
                              Row(children: [
                                Text('⭐ ${avgRating.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFFFF9800), fontSize: 13, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Text('($reviewCount reviews)', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
                              ]),
                              Text('$followers followers', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (profile['description'] != null)
                    Text(profile['description'], style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 14),

                  // Action buttons
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isFollowLoading ? null : _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? SellLiveTheme.bgCard : SellLiveTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          side: _isFollowing ? const BorderSide(color: SellLiveTheme.primaryOrange) : null,
                        ),
                        child: _isFollowLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isFollowing ? 'Following ✓' : 'Follow'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: SellLiveTheme.primaryOrange,
                          side: const BorderSide(color: SellLiveTheme.primaryOrange)),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => context.push('/go-live'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF1744),
                          side: const BorderSide(color: Color(0xFFFF1744)),
                          padding: const EdgeInsets.symmetric(horizontal: 12)),
                      child: const Text('🔴 Live', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // Stats row
                  Row(children: [
                    _Stat('${_posts.length}', 'Posts'),
                    _Stat('$followers', 'Followers'),
                    _Stat('$reviewCount', 'Reviews'),
                    _Stat('${profile['total_orders'] ?? 0}', 'Sales'),
                  ]),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                indicatorColor: SellLiveTheme.primaryOrange,
                labelColor: SellLiveTheme.primaryOrange,
                unselectedLabelColor: SellLiveTheme.textHint,
                tabs: const [Tab(text: 'Posts'), Tab(text: 'Reviews'), Tab(text: 'About')],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildPostsGrid(),
            _buildReviews(),
            _buildAbout(profile, user),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) return const Center(
      child: Text('No posts yet', style: TextStyle(color: SellLiveTheme.textHint)));
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _posts.length,
      itemBuilder: (_, i) {
        final post = _posts[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            post['thumbnail_url'] != null || post['media_url'] != null
                ? CachedNetworkImage(
                    imageUrl: post['thumbnail_url'] ?? post['media_url'],
                    fit: BoxFit.cover)
                : Container(color: SellLiveTheme.bgCard,
                    child: const Icon(Icons.image, color: SellLiveTheme.textHint)),
            if (post['media_type'] == 'video')
              const Positioned(top: 6, right: 6,
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 18)),
          ],
        );
      },
    );
  }

  Widget _buildReviews() {
    if (_reviews.isEmpty) return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_border, color: SellLiveTheme.textHint, size: 40),
        SizedBox(height: 8),
        Text('No reviews yet', style: TextStyle(color: SellLiveTheme.textHint)),
      ]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (_, i) {
        final r = _reviews[i];
        final buyer = r['buyer'] as Map? ?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 16, backgroundColor: SellLiveTheme.primaryOrange,
                  child: Text((buyer['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11))),
              const SizedBox(width: 8),
              Expanded(child: Text(buyer['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
              Row(children: List.generate(5, (j) => Icon(Icons.star, color: j < (r['rating'] as int? ?? 5) ? const Color(0xFFFF9800) : const Color(0xFF2A2A2A), size: 14))),
            ]),
            if (r['comment'] != null) ...[
              const SizedBox(height: 6),
              Text(r['comment'], style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: 4),
            Text(r['created_at']?.toString().split('T').first ?? '', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10)),
          ]),
        );
      },
    );
  }

  Widget _buildAbout(Map profile, Map user) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _AboutTile(icon: Icons.category_outlined, label: 'Category', value: profile['category'] ?? 'General'),
      _AboutTile(icon: Icons.location_on_outlined, label: 'Location', value: profile['location'] ?? 'Nigeria'),
      _AboutTile(icon: Icons.phone_outlined, label: 'Phone', value: user['phone'] ?? '—'),
      _AboutTile(icon: Icons.star_outline, label: 'Rating', value: '${(profile['avg_rating'] as num?)?.toStringAsFixed(1) ?? "5.0"} / 5.0'),
      _AboutTile(icon: Icons.verified_outlined, label: 'Verified', value: profile['is_verified'] == true ? 'Identity verified ✅' : 'Not verified'),
      _AboutTile(icon: Icons.calendar_today_outlined, label: 'Joined', value: user['created_at']?.toString().split('T').first ?? '—'),
    ],
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10)),
    ]),
  );
}

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _AboutTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
    child: Row(children: [
      Icon(icon, color: SellLiveTheme.textSecondary, size: 18),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: SellLiveTheme.bgDark, child: tabBar);
  @override bool shouldRebuild(_TabBarDelegate old) => false;
}
