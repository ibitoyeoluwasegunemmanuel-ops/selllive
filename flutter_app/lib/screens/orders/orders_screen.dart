// lib/screens/orders/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final orders = await context.read<ApiService>().getMyOrders();
      setState(() => _orders = orders);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: SellLiveTheme.bgDark,
        appBar: AppBar(title: const Text('My Orders')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  color: SellLiveTheme.textHint, size: 56),
              const SizedBox(height: 16),
              const Text('Log in to see your orders',
                  style: TextStyle(
                      color: SellLiveTheme.textPrimary, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.push('/auth/phone'),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(title: const Text('My Orders')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: SellLiveTheme.primaryOrange))
          : _orders.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: SellLiveTheme.primaryOrange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _OrderCard(order: _orders[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long,
              color: SellLiveTheme.textHint, size: 64),
          const SizedBox(height: 16),
          const Text('No orders yet',
              style: TextStyle(
                  color: SellLiveTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Buy something from a live stream!',
              style: TextStyle(color: SellLiveTheme.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Browse Live Streams'),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final product = order['product'] ?? {};
    final seller = order['seller_profile'] ?? order['seller'] ?? {};
    final amountNaira = (order['total_amount'] as int? ?? 0) / 100;
    final status = order['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SellLiveTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              _statusWidget(status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${seller['business_name'] ?? 'Seller'} · ₦${amountNaira.toStringAsFixed(0)} · qty: ${order['quantity']}',
            style: const TextStyle(
                color: SellLiveTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(order['order_ref'] ?? '',
              style: const TextStyle(
                  color: SellLiveTheme.textHint, fontSize: 11)),

          // Progress steps
          const SizedBox(height: 14),
          _buildProgress(status),

          // Review button for delivered orders
          if (status == 'delivered') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showReviewSheet(context, order['id']),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SellLiveTheme.primaryOrange,
                  side: const BorderSide(color: SellLiveTheme.primaryOrange),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Leave a Review'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusWidget(String status) {
    final colors = {
      'pending': SellLiveTheme.textHint,
      'payment_initiated': SellLiveTheme.warning,
      'paid': SellLiveTheme.success,
      'processing': SellLiveTheme.primaryOrange,
      'shipped': const Color(0xFF2196F3),
      'delivered': SellLiveTheme.success,
      'cancelled': SellLiveTheme.error,
    };
    final labels = {
      'pending': 'Pending',
      'payment_initiated': 'Paying',
      'paid': 'Paid',
      'processing': 'Packing',
      'shipped': 'Shipped',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
    };
    final color = colors[status] ?? SellLiveTheme.textHint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labels[status] ?? status,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildProgress(String status) {
    final steps = ['paid', 'processing', 'delivered'];
    final currentStep = steps.indexOf(status).clamp(0, 2);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.index;
        final label = ['Paid', 'Packing', 'Delivered'][i];
        final isCompleted = i <= currentStep;
        final isCurrent = i == currentStep;

        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? SellLiveTheme.primaryOrange
                        : const Color(0xFF333333),
                  ),
                ),
              Column(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? SellLiveTheme.primaryOrange
                          : const Color(0xFF333333),
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(
                              color: SellLiveTheme.primaryOrange, width: 2)
                          : null,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                        color: isCompleted
                            ? Colors.white
                            : SellLiveTheme.textHint,
                        fontSize: 9,
                      )),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentStep
                        ? SellLiveTheme.primaryOrange
                        : const Color(0xFF333333),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showReviewSheet(BuildContext context, String orderId) {
    int rating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rate your order',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (i) => GestureDetector(
                          onTap: () => setSt(() => rating = i + 1),
                          child: Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFFC107),
                            size: 36,
                          ),
                        )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: 'Comment (optional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.read<ApiService>().submitReview(
                      orderId: orderId,
                      rating: rating,
                      comment: commentController.text,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Review submitted! Thank you.')));
                  },
                  child: const Text('Submit Review'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
