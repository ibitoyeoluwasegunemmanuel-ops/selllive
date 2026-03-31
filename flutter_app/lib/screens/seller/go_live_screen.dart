// lib/screens/seller/go_live_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Product fields
  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productStockController = TextEditingController(text: '10');

  Future<void> _startStream() async {
    final title = _titleController.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Give your stream a title (at least 3 characters)');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await context.read<ApiService>().goLive(
        title: title,
        description: _descController.text.trim(),
      );

      final streamId = result['stream']['id'];

      // Pin first product if provided
      final productName = _productNameController.text.trim();
      final productPrice = double.tryParse(_productPriceController.text);
      if (productName.isNotEmpty && productPrice != null) {
        await context.read<ApiService>().pinProduct(
          streamId: streamId,
          name: productName,
          price: productPrice,
          position: 1,
          stock: int.tryParse(_productStockController.text) ?? 10,
        );
      }

      if (!mounted) return;
      // Navigate to the live stream screen (seller view)
      context.go('/stream/$streamId');
    } catch (e) {
      setState(() => _error = 'Failed to start stream. Check your connection.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: const Text('Go Live'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stream preview placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0500),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: SellLiveTheme.primaryOrange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam,
                        color: SellLiveTheme.primaryOrange, size: 32),
                  ),
                  const SizedBox(height: 12),
                  const Text('Camera preview',
                      style: TextStyle(color: SellLiveTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Will activate when you go live',
                      style: TextStyle(
                          color: SellLiveTheme.textHint, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionLabel('Stream title *'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. "Fresh Ankara dresses — only today!"',
              ),
            ),
            const SizedBox(height: 16),

            _sectionLabel('Description (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Tell viewers what you\'re selling',
              ),
            ),
            const SizedBox(height: 28),

            // First product to pin
            Container(
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
                      const Icon(Icons.sell,
                          color: SellLiveTheme.primaryOrange, size: 18),
                      const SizedBox(width: 8),
                      const Text('Pin a product to sell',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const Spacer(),
                      const Text('optional',
                          style: TextStyle(
                              color: SellLiveTheme.textHint, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _productNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Product name',
                      prefixIcon: Icon(Icons.shopping_bag_outlined,
                          color: SellLiveTheme.textHint, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _productPriceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Price (₦)',
                            prefixIcon: Icon(Icons.attach_money,
                                color: SellLiveTheme.textHint, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _productStockController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Stock',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(
                      color: SellLiveTheme.error, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startStream,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                label: Text(_isLoading ? 'Starting...' : 'GO LIVE NOW',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: SellLiveTheme.liveRed,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: SellLiveTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }
}
