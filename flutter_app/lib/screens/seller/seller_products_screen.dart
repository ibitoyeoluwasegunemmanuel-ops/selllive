// lib/screens/seller/seller_products_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});
  @override State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiService>().get('/products/my');
      setState(() => _products = data['products'] ?? []);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _addProduct() => _showProductSheet(context, null);

  void _editProduct(Map<String,dynamic> product) => _showProductSheet(context, product);

  Future<void> _deleteProduct(String id) async {
    await context.read<ApiService>().delete('/products/$id');
    setState(() => _products.removeWhere((p) => p['id'] == id));
  }

  void _showProductSheet(BuildContext context, Map<String,dynamic>? existing) {
    final nameCtrl  = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? ((existing['price'] as int) / 100).toStringAsFixed(0) : '');
    final stockCtrl = TextEditingController(text: existing?['stock']?.toString() ?? '');
    final descCtrl  = TextEditingController(text: existing?['description'] ?? '');
    bool isActive   = existing?['is_active'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SellLiveTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(existing == null ? 'Add Product' : 'Edit Product',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                IconButton(icon: const Icon(Icons.close, color: SellLiveTheme.textHint), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 14),
              _field(nameCtrl, 'Product Name', hint: 'e.g. Ankara Print Dress'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(priceCtrl, 'Price (₦)', hint: '8500', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(stockCtrl, 'Stock Qty', hint: '10', keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              _field(descCtrl, 'Description (optional)', hint: 'Describe your product', maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(child: Text('Available for purchase', style: TextStyle(color: Colors.white, fontSize: 13))),
                Switch(value: isActive, onChanged: (v) => setSt(() => isActive = v), activeColor: SellLiveTheme.primaryOrange),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  final name  = nameCtrl.text.trim();
                  final price = int.tryParse(priceCtrl.text.trim());
                  if (name.isEmpty || price == null || price < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid name and price')));
                    return;
                  }
                  final body = {
                    'name': name,
                    'price': price * 100, // convert to kobo
                    'stock': int.tryParse(stockCtrl.text) ?? 999,
                    'description': descCtrl.text.trim(),
                    'is_active': isActive,
                  };
                  if (existing == null) {
                    await context.read<ApiService>().post('/products', body);
                  } else {
                    await context.read<ApiService>().patch('/products/${existing['id']}', body);
                  }
                  if (context.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: Text(existing == null ? 'Add Product' : 'Save Changes'),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint, TextInputType? keyboard, int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(controller: ctrl, keyboardType: keyboard, maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(hintText: hint)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: const Text('My Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addProduct,
            tooltip: 'Add product',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        backgroundColor: SellLiveTheme.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange))
          : _products.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inventory_2_outlined, color: SellLiveTheme.textHint, size: 56),
                  const SizedBox(height: 12),
                  const Text('No products yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Add products to show in your streams and posts', style: TextStyle(color: SellLiveTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add First Product')),
                ]))
              : RefreshIndicator(
                  color: SellLiveTheme.primaryOrange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (_, i) => _ProductCard(
                      product: _products[i],
                      onEdit: () => _editProduct(_products[i] as Map<String,dynamic>),
                      onDelete: () => _deleteProduct(_products[i]['id']),
                    ),
                  ),
                ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String,dynamic> product;
  final VoidCallback onEdit, onDelete;
  const _ProductCard({required this.product, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final price   = (product['price'] as int? ?? 0) / 100;
    final active  = product['is_active'] == true;
    final stock   = product['stock'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SellLiveTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? const Color(0xFF2A2A2A) : const Color(0xFF2A2A2A)),
        opacity: active ? 1.0 : 0.6,
      ),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF1A0A00), borderRadius: BorderRadius.circular(10)),
            child: product['image_url'] != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(product['image_url'], fit: BoxFit.cover))
                : const Icon(Icons.shopping_bag_outlined, color: SellLiveTheme.primaryOrange, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(product['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (!active) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(4)),
                child: const Text('Inactive', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 9, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 3),
          Text('₦${price.toStringAsFixed(0)} · Stock: $stock', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600)),
          if (product['description'] != null && (product['description'] as String).isNotEmpty)
            Text(product['description'], style: const TextStyle(color: SellLiveTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        PopupMenuButton<String>(
          color: SellLiveTheme.bgCard,
          icon: const Icon(Icons.more_vert, color: SellLiveTheme.textHint, size: 18),
          onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'delete') onDelete(); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: Colors.white), SizedBox(width: 8), Text('Edit', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Color(0xFFF44336)), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Color(0xFFF44336)))])),
          ],
        ),
      ]),
    );
  }
}
