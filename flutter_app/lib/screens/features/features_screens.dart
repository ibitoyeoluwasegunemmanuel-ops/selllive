// lib/screens/features/features_screens.dart
// Flash Sales, Referral, Address Book, Disputes, Analytics
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

// ============================================================
// FLASH SALES SCREEN
// ============================================================
class FlashSalesScreen extends StatefulWidget {
  const FlashSalesScreen({super.key});
  @override State<FlashSalesScreen> createState() => _FlashSalesScreenState();
}

class _FlashSalesScreenState extends State<FlashSalesScreen> {
  List<dynamic> _sales = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().getFlashSales();
      setState(() => _sales = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SellLiveTheme.bgDark,
    appBar: AppBar(title: const Text('⚡ Flash Sales')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
        : _sales.isEmpty
            ? const Center(child: Text('No active flash sales right now', style: TextStyle(color: SellLiveTheme.textHint)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sales.length,
                itemBuilder: (_, i) => _FlashSaleCard(sale: _sales[i]),
              ),
  );
}

class _FlashSaleCard extends StatefulWidget {
  final Map<String, dynamic> sale;
  const _FlashSaleCard({required this.sale});
  @override State<_FlashSaleCard> createState() => _FlashSaleCardState();
}

class _FlashSaleCardState extends State<_FlashSaleCard> {
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      _updateRemaining();
      return true;
    });
  }

  void _updateRemaining() {
    final end = DateTime.tryParse(widget.sale['ends_at'] ?? '') ?? DateTime.now();
    setState(() => _remaining = end.difference(DateTime.now()));
  }

  String get _timer {
    if (_remaining.isNegative) return 'ENDED';
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.sale['products'] as List? ?? [];
    final seller = widget.sale['seller_profile'] ?? {};
    final discount = widget.sale['discount_percent'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(
        children: [
          // Header with countdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFE64A19)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.sale['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${seller['business_name'] ?? ''} · $discount% OFF', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('ENDS IN', style: TextStyle(color: Colors.white60, fontSize: 9, letterSpacing: 1)),
                    Text(_timer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
          // Products
          ...products.take(3).map((p) {
            final original = (p['original_price'] as int? ?? 0) / 100;
            final sale = (p['sale_price'] as int? ?? 0) / 100;
            return ListTile(
              leading: Container(
                width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF2A1A0A), borderRadius: BorderRadius.circular(8)),
                child: p['image_url'] != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['image_url'], fit: BoxFit.cover)) : const Icon(Icons.shopping_bag, color: SellLiveTheme.primaryOrange),
              ),
              title: Text(p['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Row(children: [
                Text('₦${sale.toStringAsFixed(0)}', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Text('₦${original.toStringAsFixed(0)}', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 11, decoration: TextDecoration.lineThrough)),
              ]),
              trailing: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: const TextStyle(fontSize: 11)),
                child: const Text('Buy'),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================
// REFERRAL SCREEN
// ============================================================
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await context.read<ApiService>().getReferralData();
      setState(() => _data = d);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SellLiveTheme.bgDark,
    appBar: AppBar(title: const Text('Refer & Earn')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Hero banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFE64A19)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    const Text('Earn ₦500 per seller you invite!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    const Text('When they make their first sale, you both earn.', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats
              Row(children: [
                _StatBox(label: 'Total Invited', value: '${_data?['stats']?['total_referrals'] ?? 0}'),
                const SizedBox(width: 10),
                _StatBox(label: 'Earned', value: '₦${(_data?['stats']?['total_earned_naira'] ?? 0).toStringAsFixed(0)}', color: SellLiveTheme.success),
                const SizedBox(width: 10),
                _StatBox(label: 'Pending', value: '${_data?['stats']?['pending'] ?? 0}', color: SellLiveTheme.warning),
              ]),
              const SizedBox(height: 24),

              // Referral code
              const Text('Your Referral Code', style: TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _data?['referral_code'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SellLiveTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SellLiveTheme.primaryOrange.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_data?['referral_code'] ?? '', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3)),
                      const SizedBox(width: 12),
                      const Icon(Icons.copy, color: SellLiveTheme.primaryOrange, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Share button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = _data?['whatsapp_share_text'] ?? '';
                    Share.share(text);
                  },
                  icon: const Text('📤', style: TextStyle(fontSize: 16)),
                  label: const Text('Share via WhatsApp'),
                ),
              ),
            ],
          ),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ============================================================
// ADDRESS BOOK SCREEN
// ============================================================
class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});
  @override State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  List<dynamic> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try { _addresses = await context.read<ApiService>().getAddresses(); } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _addAddress() {
    final labelCtrl = TextEditingController(text: 'Home');
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: labelCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Label (Home, Office...)')),
            const SizedBox(height: 10),
            TextField(controller: addressCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Full address')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Phone number')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<ApiService>().addAddress(label: labelCtrl.text, fullAddress: addressCtrl.text, phone: phoneCtrl.text);
                  Navigator.pop(context);
                  _load();
                },
                child: const Text('Save Address'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SellLiveTheme.bgDark,
    appBar: AppBar(title: const Text('Address Book'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addAddress)]),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
        : _addresses.isEmpty
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, color: SellLiveTheme.textHint, size: 56),
                  const SizedBox(height: 12),
                  const Text('No saved addresses', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _addAddress, child: const Text('Add Address')),
                ],
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _addresses.length,
                itemBuilder: (_, i) {
                  final a = _addresses[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: a['is_default'] == true ? SellLiveTheme.primaryOrange : const Color(0xFF2A2A2A)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: a['is_default'] == true ? SellLiveTheme.primaryOrange : SellLiveTheme.textHint),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(a['label'] ?? 'Home', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              if (a['is_default'] == true) ...[
                                const SizedBox(width: 6),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: SellLiveTheme.primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('DEFAULT', style: TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 9, fontWeight: FontWeight.w800))),
                              ],
                            ]),
                            Text(a['full_address'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
                            Text(a['phone'] ?? '', style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 11)),
                          ],
                        )),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: SellLiveTheme.textHint, size: 18),
                          onPressed: () async {
                            await context.read<ApiService>().deleteAddress(a['id']);
                            _load();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
  );
}

// ============================================================
// DISPUTES SCREEN
// ============================================================
class DisputesScreen extends StatefulWidget {
  final String? orderId;
  const DisputesScreen({this.orderId, super.key});
  @override State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<dynamic> _disputes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.orderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDispute());
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try { _disputes = await context.read<ApiService>().getDisputes(); } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _openDispute() {
    if (widget.orderId == null) return;
    String _reason = 'not_delivered';
    final _descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Open Dispute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _reason,
                dropdownColor: SellLiveTheme.bgCard,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'not_delivered', child: Text('Item not delivered')),
                  DropdownMenuItem(value: 'wrong_item', child: Text('Wrong item received')),
                  DropdownMenuItem(value: 'damaged', child: Text('Item damaged')),
                  DropdownMenuItem(value: 'not_as_described', child: Text('Not as described')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setSt(() => _reason = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: _descCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Describe the issue...')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: SellLiveTheme.error),
                  onPressed: () async {
                    await context.read<ApiService>().openDispute(orderId: widget.orderId!, reason: _reason, description: _descCtrl.text);
                    Navigator.pop(context);
                    _load();
                  },
                  child: const Text('Submit Dispute'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SellLiveTheme.bgDark,
    appBar: AppBar(title: const Text('Disputes')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
        : _disputes.isEmpty
            ? const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: SellLiveTheme.textHint, size: 56),
                  SizedBox(height: 12),
                  Text('No disputes', style: TextStyle(color: Colors.white)),
                  SizedBox(height: 4),
                  Text('All orders resolved ✓', style: TextStyle(color: SellLiveTheme.success)),
                ],
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _disputes.length,
                itemBuilder: (_, i) {
                  final d = _disputes[i];
                  final statusColors = {'open': SellLiveTheme.error, 'under_review': SellLiveTheme.warning, 'resolved_buyer': SellLiveTheme.success, 'resolved_seller': SellLiveTheme.primaryOrange, 'closed': SellLiveTheme.textHint};
                  final color = statusColors[d['status']] ?? SellLiveTheme.textHint;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(d['order']?['order_ref'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                              child: Text((d['status'] as String).replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800))),
                        ]),
                        const SizedBox(height: 4),
                        Text(d['description'] ?? '', style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (d['resolution'] != null) ...[
                          const SizedBox(height: 6),
                          Text('Resolution: ${d['resolution']}', style: const TextStyle(color: SellLiveTheme.success, fontSize: 11)),
                        ],
                      ],
                    ),
                  );
                },
              ),
  );
}

// ============================================================
// ANALYTICS SCREEN (Seller)
// ============================================================
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try { _data = await context.read<ApiService>().getAnalytics(); } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] ?? {};
    final chart = _data?['revenue_chart'] as List? ?? [];
    final streams = _data?['streams'] ?? {};
    final posts = _data?['posts'] ?? {};
    final maxRevenue = chart.isEmpty ? 1.0 : chart.map((d) => (d['amount'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(title: const Text('Analytics'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
                  children: [
                    _AnalyticsCard(label: 'Total Revenue', value: '₦${_fmt(summary['total_revenue_naira'])}', icon: Icons.trending_up, color: SellLiveTheme.success),
                    _AnalyticsCard(label: 'Total Orders', value: '${summary['total_orders'] ?? 0}', icon: Icons.shopping_bag, color: SellLiveTheme.primaryOrange),
                    _AnalyticsCard(label: 'Wallet Balance', value: '₦${_fmt(summary['wallet_balance_naira'])}', icon: Icons.account_balance_wallet, color: const Color(0xFF2196F3)),
                    _AnalyticsCard(label: 'Commission Paid', value: '₦${_fmt(summary['total_commission_paid_naira'])}', icon: Icons.percent, color: SellLiveTheme.warning),
                  ],
                ),
                const SizedBox(height: 20),

                // Revenue chart (7 days)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Revenue (Last 7 Days)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: chart.map((d) {
                            final amount = (d['amount'] as num).toDouble();
                            final height = maxRevenue > 0 ? (amount / maxRevenue * 80).clamp(3.0, 80.0) : 3.0;
                            final date = (d['date'] as String).split('-').last;
                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(height: height, margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(color: amount > 0 ? SellLiveTheme.primaryOrange : const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(height: 4),
                                  Text(date, style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 9)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Streams & Posts stats
                Row(children: [
                  Expanded(child: _StatsBlock(
                    title: '📺 Streams',
                    items: [
                      ('Total', '${streams['total'] ?? 0}'),
                      ('Avg Viewers', '${streams['avg_viewers'] ?? 0}'),
                    ],
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _StatsBlock(
                    title: '📱 Shop Posts',
                    items: [
                      ('Total Posts', '${posts['total'] ?? 0}'),
                      ('Total Views', _fmt(posts['total_views'])),
                      ('Total Likes', _fmt(posts['total_likes'])),
                      ('Engagement', '${posts['engagement_rate'] ?? 0}%'),
                    ],
                  )),
                ]),
              ],
            ),
    );
  }

  String _fmt(dynamic v) {
    final n = (v as num?)?.toDouble() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(0);
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AnalyticsCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: color, size: 22),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: SellLiveTheme.textHint, fontSize: 10)),
        ]),
      ],
    ),
  );
}

class _StatsBlock extends StatelessWidget {
  final String title;
  final List<(String, String)> items;
  const _StatsBlock({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.$1, style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11)),
              Text(item.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
            ],
          ),
        )),
      ],
    ),
  );
}
