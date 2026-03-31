// lib/screens/home/home_screen.dart — Live Feed (Buyer Home)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> _streams = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  Future<void> _loadStreams() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final streams = await context.read<ApiService>().getStreams();
      setState(() { _streams = streams; });
    } catch (e) {
      setState(() { _hasError = true; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Sell',
                style: TextStyle(
                  color: SellLiveTheme.primaryOrange,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: 'Live',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (auth.isSeller)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/go-live'),
                icon: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                label: const Text('GO LIVE'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: SellLiveTheme.primaryOrange,
        onRefresh: _loadStreams,
        child: _isLoading
            ? _buildSkeleton()
            : _hasError
                ? _buildError()
                : _streams.isEmpty
                    ? _buildEmpty()
                    : _buildFeed(),
      ),
    );
  }

  Widget _buildFeed() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _streams.length,
      itemBuilder: (context, index) => StreamCard(
        stream: _streams[index],
        onTap: () => context.push('/stream/${_streams[index]['id']}'),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: SellLiveTheme.bgCard,
      highlightColor: SellLiveTheme.bgCardElevated,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 220,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: SellLiveTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: SellLiveTheme.textHint, size: 48),
          const SizedBox(height: 12),
          const Text('Could not load streams', style: TextStyle(color: SellLiveTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStreams, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.live_tv, color: SellLiveTheme.textHint, size: 64),
          const SizedBox(height: 12),
          const Text('No live streams right now',
              style: TextStyle(color: SellLiveTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Check back soon or follow sellers to get notified',
              style: TextStyle(color: SellLiveTheme.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ============================================================
// STREAM CARD WIDGET
// ============================================================
class StreamCard extends StatelessWidget {
  final Map<String, dynamic> stream;
  final VoidCallback onTap;

  const StreamCard({required this.stream, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final seller = stream['seller'] ?? {};
    final sellerProfile = stream['seller_profile'] ?? {};
    final products = (stream['products'] as List?)
        ?.where((p) => p['is_active'] == true)
        .toList() ?? [];
    final lowestPrice = products.isNotEmpty
        ? products.map((p) => p['price'] as int).reduce((a, b) => a < b ? a : b)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: SellLiveTheme.bgCard,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: stream['thumbnail_url'] != null
                  ? CachedNetworkImage(
                      imageUrl: stream['thumbnail_url'],
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: const Color(0xFF1A0A00),
                      child: const Icon(Icons.live_tv, color: Color(0xFF333333), size: 48),
                    ),
            ),

            // Gradient overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // LIVE badge (top left)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Viewer count (top right)
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatViewers(stream['viewer_count'] ?? 0),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom info
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seller info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: SellLiveTheme.primaryOrange,
                        backgroundImage: seller['avatar_url'] != null
                            ? CachedNetworkImageProvider(seller['avatar_url']) : null,
                        child: seller['avatar_url'] == null
                            ? Text(
                                (seller['name'] ?? 'S').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sellerProfile['business_name'] ?? seller['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (sellerProfile['trust_score'] != null)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFFFC107), size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${sellerProfile['trust_score']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Stream title
                  Text(
                    stream['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Price
                  if (lowestPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'from ${(lowestPrice / 100).toStringAsFixed(0)} ₦',
                      style: const TextStyle(
                        color: SellLiveTheme.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewers(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}
