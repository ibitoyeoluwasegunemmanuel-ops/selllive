// lib/screens/orders/orders_screen.dart
// Full order history + real-time tracking with timeline
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try { final data = await context.read<ApiService>().getOrders(); setState(() => _orders = data); } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SellLiveTheme.bgDark,
    appBar: AppBar(
      title: const Text('Orders'),
      bottom: TabBar(
        controller: _tabs,
        indicatorColor: SellLiveTheme.primaryOrange,
        labelColor: SellLiveTheme.primaryOrange,
        unselectedLabelColor: SellLiveTheme.textHint,
        tabs: const [Tab(text: 'Active'), Tab(text: 'Completed')],
      ),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
        : RefreshIndicator(
            color: SellLiveTheme.primaryOrange,
            onRefresh: _load,
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildList(_orders.where((o) => !['delivered','cancelled'].contains(o['status'])).toList()),
                _buildList(_orders.where((o) =>  ['delivered','cancelled'].contains(o['status'])).toList()),
              ],
            ),
          ),
  );

  Widget _buildList(List<dynamic> orders) {
    if (orders.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.shopping_bag_outlined, color: SellLiveTheme.textHint, size: 56),
      const SizedBox(height: 12),
      const Text('No orders here', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Browse Live Streams')),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(order: orders[i], onTap: () => _showDetail(orders[i])),
    );
  }

  void _showDetail(Map<String,dynamic> order) => showModalBottomSheet(
    context: context,
    backgroundColor: SellLiveTheme.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _OrderDetailSheet(order: order),
  );
}

class _OrderCard extends StatelessWidget {
  final Map<String,dynamic> order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  static const _statusColors = {
    'pending': Color(0xFF666666), 'payment_initiated': Color(0xFF2196F3),
    'paid': Color(0xFF4CAF50), 'processing': Color(0xFFFF9800),
    'shipped': Color(0xFF9C27B0), 'delivered': Color(0xFF4CAF50), 'cancelled': Color(0xFFF44336),
  };
  static const _statusLabels = {
    'pending': 'Pending', 'payment_initiated': 'Processing Payment',
    'paid': 'Paid — Packing', 'processing': 'Being Prepared',
    'shipped': 'On the Way 📦', 'delivered': 'Delivered ✅', 'cancelled': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final color  = _statusColors[status] ?? const Color(0xFF666666);
    final label  = _statusLabels[status] ?? status;
    final amount = (order['total_amount'] as int? ?? 0) / 100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order['order_ref'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(order['product']?['name'] ?? 'Your order', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₦${amount.toStringAsFixed(0)}', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800))),
              ]),
            ]),
          ),
          if (!['delivered','cancelled'].contains(status)) _ProgressBar(status: status),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF2A2A2A)))),
            child: Row(children: [
              const Icon(Icons.access_time, color: SellLiveTheme.textHint, size: 12),
              const SizedBox(width: 4),
              Text(order['created_at']?.toString().split('T').first ?? '', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
              const Spacer(),
              const Text('View details →', style: TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String status;
  const _ProgressBar({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = ['paid','processing','shipped','delivered'];
    final idx = steps.indexOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF2A2A2A)))),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Container(height: 2, color: i ~/ 2 < idx ? SellLiveTheme.primaryOrange : const Color(0xFF2A2A2A)));
          }
          final di = i ~/ 2;
          final done = di <= idx;
          return Column(children: [
            Container(width: 20, height: 20,
              decoration: BoxDecoration(color: done ? SellLiveTheme.primaryOrange : const Color(0xFF2A2A2A), shape: BoxShape.circle),
              child: done ? const Icon(Icons.check, color: Colors.white, size: 12) : null),
            const SizedBox(height: 3),
            Text(['Paid','Packing','Shipped','Done'][di],
                style: TextStyle(color: done ? SellLiveTheme.primaryOrange : SellLiveTheme.textHint, fontSize: 8, fontWeight: FontWeight.w600)),
          ]);
        }),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final Map<String,dynamic> order;
  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final status  = order['status'] as String? ?? 'pending';
    final amount  = (order['total_amount'] as int? ?? 0) / 100;
    final seller  = order['seller'] as Map? ?? {};
    final tracking = order['tracking_number'];

    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Expanded(child: Text(order['order_ref'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
            IconButton(icon: const Icon(Icons.close, color: SellLiveTheme.textHint), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),

          // Product block
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SellLiveTheme.bgCardElevated, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF2A1A0A), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shopping_bag, color: SellLiveTheme.primaryOrange)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order['product']?['name'] ?? 'Your order', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                Text('Qty: ${order['quantity'] ?? 1}', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
              ])),
              Text('₦${amount.toStringAsFixed(0)}', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 14),

          // Tracking
          if (tracking != null) ...[
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: SellLiveTheme.bgCardElevated, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.local_shipping_outlined, color: SellLiveTheme.primaryOrange),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order['logistics_provider'] ?? 'GIG Logistics', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('Tracking: $tracking', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // Delivery
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SellLiveTheme.bgCardElevated, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DELIVERY', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(order['delivery_address'] ?? 'No address', style: const TextStyle(color: Colors.white, fontSize: 13)),
              if (order['delivery_phone'] != null) Text(order['delivery_phone'], style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),

          // Seller
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SellLiveTheme.bgCardElevated, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(radius: 20, backgroundColor: SellLiveTheme.primaryOrange,
                  child: Text((seller['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Text(seller['name'] ?? 'Seller', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), side: const BorderSide(color: SellLiveTheme.primaryOrange)),
                child: const Text('Chat', style: TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          if (status == 'delivered')
            ElevatedButton(onPressed: () {}, child: const Text('Leave a Review ⭐')),
          if (['paid','processing','shipped'].contains(status))
            OutlinedButton(
              onPressed: () { Navigator.pop(context); context.push('/disputes', extra: order['id']); },
              style: OutlinedButton.styleFrom(foregroundColor: SellLiveTheme.error, side: const BorderSide(color: SellLiveTheme.error)),
              child: const Text('Open Dispute'),
            ),
        ],
      ),
    );
  }
}
