// lib/screens/search/search_screen.dart
// Unified search across streams, posts, sellers, and products
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({this.initialQuery, super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabs;
  bool _isSearching = false;
  String _lastQuery = '';

  Map<String, List<dynamic>> _results = {'streams': [], 'posts': [], 'sellers': [], 'products': []};

  final List<String> _recentSearches = ['ankara dress', 'iPhone 14', 'glow serum', 'kitchen set'];
  final List<Map<String,String>> _trending = [
    {'label': '👗 Ankara', 'q': 'ankara'},
    {'label': '📱 iPhone', 'q': 'iphone'},
    {'label': '💄 Skincare', 'q': 'skincare'},
    {'label': '👠 Shoes', 'q': 'shoes'},
    {'label': '🧵 Lace fabric', 'q': 'lace'},
    {'label': '🍲 Jollof', 'q': 'food'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    if (widget.initialQuery != null) {
      _searchCtrl.text = widget.initialQuery!;
      _search(widget.initialQuery!);
    }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty || q == _lastQuery) return;
    _lastQuery = q.trim();
    setState(() => _isSearching = true);
    try {
      final data = await context.read<ApiService>().searchAll(q.trim());
      setState(() => _results = {
        'streams':  (data['streams']  as List? ?? []),
        'posts':    (data['posts']    as List? ?? []),
        'sellers':  (data['sellers']  as List? ?? []),
        'products': (data['products'] as List? ?? []),
      });
    } catch (_) {}
    setState(() => _isSearching = false);
  }

  int get _totalResults => _results.values.fold(0, (s, l) => s + l.length);

  @override
  Widget build(BuildContext context) {
    final hasResults = _lastQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        backgroundColor: SellLiveTheme.bgDark,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search products, sellers, streams...',
            hintStyle: const TextStyle(color: SellLiveTheme.textHint, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: SellLiveTheme.textHint, size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() { _lastQuery = ''; _results = {'streams':[],'posts':[],'sellers':[],'products':[]}; }); })
                : null,
          ),
          onChanged: (v) {
            setState(() {});
            if (v.length >= 2) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (_searchCtrl.text == v) _search(v);
              });
            }
          },
          onSubmitted: _search,
        ),
        bottom: hasResults ? TabBar(
          controller: _tabs,
          indicatorColor: SellLiveTheme.primaryOrange,
          labelColor: SellLiveTheme.primaryOrange,
          unselectedLabelColor: SellLiveTheme.textHint,
          isScrollable: true,
          tabs: [
            Tab(text: 'All (${_totalResults})'),
            Tab(text: 'Streams (${_results['streams']!.length})'),
            Tab(text: 'Sellers (${_results['sellers']!.length})'),
            Tab(text: 'Posts (${_results['posts']!.length})'),
          ],
        ) : null,
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : !hasResults
              ? _buildDiscovery()
              : _totalResults == 0
                  ? _buildEmpty()
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildAllResults(),
                        _buildStreamResults(),
                        _buildSellerResults(),
                        _buildPostResults(),
                      ],
                    ),
    );
  }

  Widget _buildDiscovery() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRENDING SEARCHES', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _trending.map((t) => GestureDetector(
            onTap: () { _searchCtrl.text = t['q']!; _search(t['q']!); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2A2A2A))),
              child: Text(t['label']!, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 28),
        const Text('RECENT SEARCHES', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        ..._recentSearches.map((q) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history, color: SellLiveTheme.textHint, size: 20),
          title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 14)),
          onTap: () { _searchCtrl.text = q; _search(q); },
          trailing: const Icon(Icons.north_west, color: SellLiveTheme.textHint, size: 16),
        )),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off, color: SellLiveTheme.textHint, size: 56),
      const SizedBox(height: 12),
      Text('No results for "$_lastQuery"', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Try different keywords or browse categories', style: TextStyle(color: SellLiveTheme.textSecondary)),
    ]),
  );

  Widget _buildAllResults() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (_results['streams']!.isNotEmpty) ...[
        _SectionHeader('🔴 Live Streams', _results['streams']!.length),
        ..._results['streams']!.take(3).map((s) => _StreamTile(stream: s, onTap: () => context.push('/stream/${s['id']}'))),
      ],
      if (_results['sellers']!.isNotEmpty) ...[
        _SectionHeader('🏪 Sellers', _results['sellers']!.length),
        ..._results['sellers']!.take(3).map((s) => _SellerTile(seller: s, onTap: () => context.push('/seller/${s['user']?['id']}'))),
      ],
      if (_results['posts']!.isNotEmpty) ...[
        _SectionHeader('📱 Shop Posts', _results['posts']!.length),
        ..._results['posts']!.take(3).map((p) => _PostTile(post: p)),
      ],
    ],
  );

  Widget _buildStreamResults() => ListView(
    padding: const EdgeInsets.all(16),
    children: _results['streams']!.map((s) => _StreamTile(stream: s, onTap: () => context.push('/stream/${s['id']}'))).toList(),
  );

  Widget _buildSellerResults() => ListView(
    padding: const EdgeInsets.all(16),
    children: _results['sellers']!.map((s) => _SellerTile(seller: s, onTap: () => context.push('/seller/${s['user']?['id']}'))).toList(),
  );

  Widget _buildPostResults() => ListView(
    padding: const EdgeInsets.all(16),
    children: _results['posts']!.map((p) => _PostTile(post: p)).toList(),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader(this.title, this.count);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      const Spacer(),
      Text('$count found', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 12)),
    ]),
  );
}

class _StreamTile extends StatelessWidget {
  final Map<String,dynamic> stream;
  final VoidCallback onTap;
  const _StreamTile({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF1A0A00), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.live_tv, color: SellLiveTheme.primaryOrange)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stream['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(stream['seller_profile']?['business_name'] ?? stream['seller']?['name'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11)),
          Row(children: [
            const Icon(Icons.remove_red_eye_outlined, color: SellLiveTheme.textHint, size: 12),
            const SizedBox(width: 3),
            Text('${stream['viewer_count'] ?? 0}', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
          ]),
        ])),
        if (stream['status'] == 'live')
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFF1744), borderRadius: BorderRadius.circular(5)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
      ]),
    ),
  );
}

class _SellerTile extends StatelessWidget {
  final Map<String,dynamic> seller;
  final VoidCallback onTap;
  const _SellerTile({required this.seller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = seller['user'] ?? {};
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          CircleAvatar(radius: 24, backgroundColor: SellLiveTheme.primaryOrange,
              backgroundImage: user['avatar_url'] != null ? CachedNetworkImageProvider(user['avatar_url']) : null,
              child: user['avatar_url'] == null ? Text((user['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(seller['business_name'] ?? user['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              if (seller['is_verified'] == true) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: SellLiveTheme.primaryOrange, size: 14)],
            ]),
            Text('${seller['followers_count'] ?? 0} followers · ⭐ ${seller['avg_rating'] ?? '5.0'}', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11)),
          ])),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), side: const BorderSide(color: SellLiveTheme.primaryOrange)),
            child: const Text('View', style: TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String,dynamic> post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final products = (post['products'] as List? ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: post['thumbnail_url'] != null || post['media_url'] != null
              ? CachedNetworkImage(imageUrl: post['thumbnail_url'] ?? post['media_url'], width: 52, height: 52, fit: BoxFit.cover)
              : Container(width: 52, height: 52, color: const Color(0xFF1A0A00), child: const Icon(Icons.image, color: SellLiveTheme.textHint)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post['caption'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (products.isNotEmpty) Text('${products.first['name']} — ₦${((products.first['price'] as int? ?? 0) / 100).toStringAsFixed(0)}',
              style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('❤ ${post['like_count'] ?? 0} · 👁 ${post['view_count'] ?? 0}', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
        ])),
      ]),
    );
  }
}
