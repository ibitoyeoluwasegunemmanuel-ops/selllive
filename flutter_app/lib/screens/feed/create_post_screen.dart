// lib/screens/feed/create_post_screen.dart
// Sellers create product posts (like TikTok/Instagram)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  File? _mediaFile;
  String _mediaType = 'image';
  bool _isUploading = false;
  bool _isPosting = false;
  String? _uploadedUrl;
  String? _thumbnailUrl;

  // Products to tag
  final List<Map<String, dynamic>> _products = [];

  final _picker = ImagePicker();

  Future<void> _pickMedia(String type) async {
    XFile? file;
    if (type == 'video') {
      file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    } else {
      file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    }
    if (file == null) return;

    setState(() { _mediaFile = File(file!.path); _mediaType = type; _isUploading = true; });

    try {
      final url = await context.read<ApiService>().uploadProductImage(file.path);
      setState(() { _uploadedUrl = url; });
    } catch (e) {
      _showSnack('Upload failed. Try again.');
    }
    setState(() => _isUploading = false);
  }

  Future<void> _post() async {
    if (_uploadedUrl == null) { _showSnack('Please select a photo or video first.'); return; }

    setState(() => _isPosting = true);
    try {
      await context.read<ApiService>().createPost(
        mediaUrl: _uploadedUrl!,
        mediaType: _mediaType,
        caption: _captionCtrl.text.trim(),
        products: _products,
      );
      if (mounted) {
        _showSnack('Post published! 🎉');
        context.pop();
      }
    } catch (e) {
      _showSnack('Failed to post. Try again.');
    }
    setState(() => _isPosting = false);
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: SellLiveTheme.bgCard));

  void _addProduct() {
    if (_products.length >= 5) { _showSnack('Maximum 5 products per post.'); return; }
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

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
            const Text('Tag a Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Product name')),
            const SizedBox(height: 10),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Price in ₦', prefixText: '₦ ', prefixStyle: TextStyle(color: SellLiveTheme.primaryOrange))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text);
                  if (name.isEmpty || price == null || price < 100) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid name and price (min ₦100)')));
                    return;
                  }
                  setState(() => _products.add({'name': name, 'price': price, 'position': _products.length + 1}));
                  Navigator.pop(context);
                },
                child: const Text('Add Product'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellLiveTheme.bgDark,
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _post,
            child: _isPosting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: SellLiveTheme.primaryOrange, strokeWidth: 2))
                : const Text('POST', style: TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media picker
            GestureDetector(
              onTap: () => _showMediaPicker(),
              child: Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SellLiveTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A2A), width: 2, style: BorderStyle.solid),
                ),
                child: _isUploading
                    ? const Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: SellLiveTheme.primaryOrange),
                          SizedBox(height: 12),
                          Text('Uploading...', style: TextStyle(color: SellLiveTheme.textSecondary)),
                        ],
                      ))
                    : _mediaFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_mediaFile!, fit: BoxFit.cover),
                                if (_mediaType == 'video')
                                  const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 64)),
                                Positioned(
                                  bottom: 8, right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                    child: Text(_mediaType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(color: SellLiveTheme.primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.add_photo_alternate_outlined, color: SellLiveTheme.primaryOrange, size: 32),
                              ),
                              const SizedBox(height: 12),
                              const Text('Tap to add photo or video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              const Text('Show your product to buyers', style: TextStyle(color: SellLiveTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),

            // Caption
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Write a caption... #ankara #fashion',
                hintStyle: TextStyle(color: SellLiveTheme.textHint),
                filled: true,
                fillColor: SellLiveTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: SellLiveTheme.textHint),
              ),
            ),
            const SizedBox(height: 20),

            // Tagged products
            Row(
              children: [
                const Text('Tag Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                GestureDetector(
                  onTap: _addProduct,
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline, color: SellLiveTheme.primaryOrange, size: 18),
                      const SizedBox(width: 4),
                      const Text('Add', style: TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Buyers can tap the product to buy instantly', style: TextStyle(color: SellLiveTheme.textHint, fontSize: 12)),
            const SizedBox(height: 12),

            if (_products.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: SellLiveTheme.textHint),
                    const SizedBox(width: 10),
                    const Text('No products tagged yet', style: TextStyle(color: SellLiveTheme.textHint)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _addProduct,
                      child: const Text('+ Add', style: TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_products.length, (i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: SellLiveTheme.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2A2A2A))),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag, color: SellLiveTheme.primaryOrange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_products[i]['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Text('₦${_products[i]['price'].toStringAsFixed(0)}', style: const TextStyle(color: SellLiveTheme.primaryOrange, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _products.removeAt(i)),
                      child: const Icon(Icons.close, color: SellLiveTheme.textHint, size: 18),
                    ),
                  ],
                ),
              )),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SellLiveTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Media', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _PickerOption(icon: Icons.photo_library, label: 'Photo from Gallery', onTap: () { Navigator.pop(context); _pickMedia('image'); })),
                const SizedBox(width: 12),
                Expanded(child: _PickerOption(icon: Icons.videocam, label: 'Video from Gallery', onTap: () { Navigator.pop(context); _pickMedia('video'); })),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _PickerOption(icon: Icons.camera_alt, label: 'Take Photo', onTap: () async { Navigator.pop(context); final f = await _picker.pickImage(source: ImageSource.camera); if (f != null) { setState(() { _mediaFile = File(f.path); _mediaType = 'image'; }); } })),
                const SizedBox(width: 12),
                Expanded(child: _PickerOption(icon: Icons.fiber_manual_record, label: 'Record Video', onTap: () async { Navigator.pop(context); final f = await _picker.pickVideo(source: ImageSource.camera); if (f != null) { setState(() { _mediaFile = File(f.path); _mediaType = 'video'; }); } })),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SellLiveTheme.bgCardElevated, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: SellLiveTheme.primaryOrange, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
