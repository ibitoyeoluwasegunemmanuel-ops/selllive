// lib/screens/seller/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().getSellerDashboard();
      setState(() => _dashboard = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: SellLiveTheme.primaryOrange))
          : _dashboard == null
              ? const Center(child: Text('Failed to load',
                  style: TextStyle(color: SellLiveTheme.textSecondary)))
              : RefreshIndicator(
                  color: SellLiveTheme.primaryOrange,
                  onRefresh: _load,
                  child: _buildDashboard(),
                ),
    );
  }

  Widget _buildDashboard() {
    final stats = _dashboard!['stats'] as Map<String, dynamic>;
    final orders = _dashboard!['pending_orders'] as List? ?? [];
    final streams = _dashboard!['recent_streams'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Go Live button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/go-live'),
            icon: Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            label: const Text('GO LIVE NOW',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontSize: 15)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: SellLiveTheme.liveRed,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Stats grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              label: "Today's Revenue",
              value: '₦${_fmt(stats['today_revenue_naira'])}',
              icon: Icons.trending_up,
              color: SellLiveTheme.success,
            ),
            _StatCard(
              label: 'Followers',
              value: _fmt(stats['followers']),
              icon: Icons.people,
              color: SellLiveTheme.primaryOrange,
            ),
            _StatCard(
              label: 'Trust Score',
              value: '${stats['trust_score']} ★',
              icon: Icons.star,
              color: const Color(0xFFFFC107),
            ),
            _StatCard(
              label: 'Wallet',
              value: '₦${_fmt(stats['wallet_balance_naira'])}',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF2196F3),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Pending orders
        if (orders.isNotEmpty) ...[
          _sectionHeader('Pending Orders', '${orders.length} need action'),
          const SizedBox(height: 10),
          ...orders.map((order) => _OrderTile(
                order: order,
                onStatusUpdate: (status) async {
                  await context
                      .read<ApiService>()
                      .updateOrderStatus(order['id'], status);
                  _load();
                },
              )),
          const SizedBox(height: 24),
        ],

        // Recent streams
        if (streams.isNotEmpty) ...[
          _sectionHeader('Recent Streams', ''),
          const SizedBox(height: 10),
          ...streams.map((s) => _StreamHistoryTile(stream: s)),
        ],
      ],
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '0';
    final n = double.tryParse(value.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(0);
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        const Spacer(),
        if (subtitle.isNotEmpty)
          Text(subtitle,
              style: const TextStyle(
                  color: SellLiveTheme.primaryOrange, fontSize: 12)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SellLiveTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
              Text(label,
                  style: const TextStyle(
                      color: SellLiveTheme.textHint, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String) onStatusUpdate;

  const _OrderTile({required this.order, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final product = order['product'] ?? {};
    final buyer = order['buyer'] ?? {};
    final amountNaira = (order['total_amount'] as int) / 100;
    final status = order['status'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SellLiveTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(product['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
              _StatusBadge(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${buyer['name'] ?? 'Buyer'} · ₦${amountNaira.toStringAsFixed(0)} · ${order['order_ref']}',
            style: const TextStyle(
                color: SellLiveTheme.textSecondary, fontSize: 12),
          ),
          if (status == 'paid') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onStatusUpdate('processing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SellLiveTheme.primaryOrange,
                      side: const BorderSide(
                          color: SellLiveTheme.primaryOrange),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Start Packing'),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'processing') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onStatusUpdate('delivered'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Mark Delivered'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'paid':
        bg = SellLiveTheme.success.withOpacity(0.15);
        fg = SellLiveTheme.success;
        break;
      case 'processing':
        bg = SellLiveTheme.primaryOrange.withOpacity(0.15);
        fg = SellLiveTheme.primaryOrange;
        break;
      case 'delivered':
        bg = const Color(0xFF2196F3).withOpacity(0.15);
        fg = const Color(0xFF64B5F6);
        break;
      default:
        bg = SellLiveTheme.textHint.withOpacity(0.15);
        fg = SellLiveTheme.textHint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: fg, fontSize: 9, fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _StreamHistoryTile extends StatelessWidget {
  final Map<String, dynamic> stream;
  const _StreamHistoryTile({required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SellLiveTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: stream['status'] == 'live'
                  ? SellLiveTheme.liveRed.withOpacity(0.15)
                  : SellLiveTheme.bgCardElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              stream['status'] == 'live' ? Icons.live_tv : Icons.videocam_off,
              color: stream['status'] == 'live'
                  ? SellLiveTheme.liveRed
                  : SellLiveTheme.textHint,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stream['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                  '${stream['viewer_count'] ?? 0} viewers · ${stream['total_orders'] ?? 0} orders',
                  style: const TextStyle(
                      color: SellLiveTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (stream['status'] == 'live')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SellLiveTheme.liveRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}
