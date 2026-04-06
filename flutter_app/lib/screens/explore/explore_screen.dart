// lib/screens/explore/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchController = TextEditingController();
  List<dynamic> _trending = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final categories = [
    {'id': 'fashion', 'name': 'Fashion', 'emoji': '👗'},
    {'id': 'shoes', 'name': 'Shoes', 'emoji': '👟'},
    {'id': 'electronics', 'name': 'Electronics', 'emoji': '📱'},
    {'id': 'beauty', 'name': 'Beauty', 'emoji': '💄'},
    {'id': 'food', 'name': 'Food', 'emoji': '🍲'},
    {'id': 'fabric', 'name': 'Fabrics', 'emoji': '🧵'},
    {'id': 'jewelry', 'name': 'Jewelry', 'emoji': '💍'},
    {'id': 'home', 'name': 'Home', 'emoji': '🏠'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().getTrending();
      setState(() => _trending = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _search(String q) async {
    if (q.length < 2) return;
    setState(() => _isSearching = true);
    try {
      final data = await context.read<ApiService>().searchStreams(q);
      setState(() => _searchResults = data['streams'] ?? []);
    } catch (_) {}
    setState(() => _isSearching = false);
  }

  Future<void> _shareOnWhatsApp(String streamId) async {
    try {
      final result = await context.read<ApiService>().shareStream(streamId);
      final url = result['whatsapp_url'];
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: const Text('Explore'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: SellLiveTheme.primaryOrange,
          labelColor: SellLiveTheme.primaryOrange,
          unselectedLabelColor: SellLiveTheme.textHint,
          tabs: const [Tab(text: '🔥 Trending'), Tab(text: '🔍 Search')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildTrending(), _buildSearch()],
      ),
    );
  }

  Widget _buildTrending() {
    return RefreshIndicator(
      color: SellLiveTheme.primaryOrange,
      onRefresh: _loadTrending,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Categories
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _CategoryChip(category: categories[i]),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('🔥 Trending Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                if (_trending.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No live streams right now', style: TextStyle(color: SellLiveTheme.textHint)),
                  ))
                else
                  ..._trending.asMap().entries.map((e) => _TrendingCard(
                    rank: e.key + 1,
                    stream: e.value,
                    onTap: () => context.push('/stream/${e.value['id']}'),
                    onShare: () => _shareOnWhatsApp(e.value['id']),
                  )),
              ],
            ),
    );
  }

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search streams, sellers...',
              prefixIcon: const Icon(Icons.search, color: SellLiveTheme.textHint),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: SellLiveTheme.textHint),
                      onPressed: () { _searchController.clear(); setState(() => _searchResults = []); },
                    )
                  : null,
            ),
            onChanged: (v) {
              setState(() {});
              if (v.length >= 2) _search(v);
            },
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search, color: SellLiveTheme.textHint, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty ? 'Type to search streams and sellers' : 'No results for "${_searchController.text}"',
                            style: const TextStyle(color: SellLiveTheme.textHint),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final s = _searchResults[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: SellLiveTheme.primaryOrange,
                            backgroundImage: s['seller']?['avatar_url'] != null
                                ? CachedNetworkImageProvider(s['seller']['avatar_url']) : null,
                            child: s['seller']?['avatar_url'] == null
                                ? Text((s['seller']?['name'] ?? 'S')[0], style: const TextStyle(color: Colors.white))
                                : null,
                          ),
                          title: Text(s['title'] ?? '', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(s['seller_profile']?['business_name'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
                          trailing: s['status'] == 'live'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: SellLiveTheme.liveRed, borderRadius: BorderRadius.circular(5)),
                                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                )
                              : null,
                          onTap: () => context.push('/stream/${s['id']}'),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Map<String, dynamic> category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: SellLiveTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Center(child: Text(category['emoji']!, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(height: 6),
          Text(category['name']!, style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> stream;
  final VoidCallback onTap;
  final VoidCallback onShare;

  const _TrendingCard({required this.rank, required this.stream, required this.onTap, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final seller = stream['seller'] ?? {};
    final profile = stream['seller_profile'] ?? {};

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(
          children: [
            // Rank
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 ? SellLiveTheme.primaryOrange.withOpacity(0.2) : SellLiveTheme.bgCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(
                rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                style: TextStyle(fontSize: rank <= 3 ? 16 : 12, color: Colors.white, fontWeight: FontWeight.w700),
              )),
            ),
            const SizedBox(width: 12),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52, height: 52,
                color: const Color(0xFF1A0A00),
                child: stream['thumbnail_url'] != null
                    ? CachedNetworkImage(imageUrl: stream['thumbnail_url'], fit: BoxFit.cover)
                    : const Icon(Icons.live_tv, color: Color(0xFF333333)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stream['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(profile['business_name'] ?? seller['name'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, color: SellLiveTheme.textHint, size: 12),
                      const SizedBox(width: 3),
                      Text('${stream['viewer_count'] ?? 0}', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10)),
                      const SizedBox(width: 10),
                      const Icon(Icons.shopping_bag_outlined, color: SellLiveTheme.textHint, size: 12),
                      const SizedBox(width: 3),
                      Text('${stream['total_orders'] ?? 0}', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            // WhatsApp share button
            GestureDetector(
              onTap: onShare,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('📤', style: TextStyle(fontSize: 16))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
