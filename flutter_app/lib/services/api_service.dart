// lib/services/api_service.dart — All API calls to SellLive backend
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Change this to your deployed backend URL when ready
const String _baseUrl = 'http://localhost:3000/api';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor: attach JWT token to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Log errors in debug mode
        print('API Error: ${e.response?.statusCode} ${e.requestOptions.path}');
        print('Response: ${e.response?.data}');
        return handler.next(e);
      },
    ));
  }

  // ============================================================
  // AUTH
  // ============================================================

  Future<Map<String, dynamic>> sendOTP(String phone) async {
    final response = await _dio.post('/auth/send-otp', data: {'phone': phone});
    return response.data;
  }

  Future<Map<String, dynamic>> verifyOTP({
    required String phone,
    required String code,
    String? name,
    String role = 'buyer',
  }) async {
    final response = await _dio.post('/auth/verify-otp', data: {
      'phone': phone,
      'code': code,
      if (name != null) 'name': name,
      'role': role,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> completeSellerProfile({
    required String businessName,
    required String bankAccount,
    required String bankCode,
    required String accountName,
    String? bio,
  }) async {
    final response = await _dio.post('/auth/complete-seller-profile', data: {
      'business_name': businessName,
      'bank_account': bankAccount,
      'bank_code': bankCode,
      'account_name': accountName,
      if (bio != null) 'bio': bio,
    });
    return response.data;
  }

  // ============================================================
  // STREAMS
  // ============================================================

  Future<List<dynamic>> getStreams({int page = 1}) async {
    final response = await _dio.get('/streams', queryParameters: {'page': page});
    return response.data['streams'];
  }

  Future<Map<String, dynamic>> getStream(String streamId) async {
    final response = await _dio.get('/streams/$streamId');
    return response.data['stream'];
  }

  Future<Map<String, dynamic>> goLive({
    required String title,
    String? description,
    String? thumbnailUrl,
  }) async {
    final response = await _dio.post('/streams', data: {
      'title': title,
      if (description != null) 'description': description,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    });
    return response.data;
  }

  Future<void> endStream(String streamId) async {
    await _dio.patch('/streams/$streamId/end');
  }

  Future<Map<String, dynamic>> pinProduct({
    required String streamId,
    required String name,
    required double price,  // in naira
    required int position,
    String? imageUrl,
    int stock = 999,
  }) async {
    final response = await _dio.post('/streams/$streamId/products', data: {
      'name': name,
      'price': price,
      'position': position,
      if (imageUrl != null) 'image_url': imageUrl,
      'stock': stock,
    });
    return response.data;
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<Map<String, dynamic>> initiatePayment({
    required String productId,
    required String streamId,
    int quantity = 1,
    String? deliveryAddress,
    String? deliveryPhone,
  }) async {
    final response = await _dio.post('/payments/initiate', data: {
      'product_id': productId,
      'stream_id': streamId,
      'quantity': quantity,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryPhone != null) 'delivery_phone': deliveryPhone,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> verifyPayment(String txRef) async {
    final response = await _dio.get('/payments/verify/$txRef');
    return response.data;
  }

  // ============================================================
  // ORDERS
  // ============================================================

  Future<List<dynamic>> getMyOrders() async {
    final response = await _dio.get('/orders');
    return response.data['orders'];
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _dio.patch('/orders/$orderId/status', data: {'status': status});
  }

  // ============================================================
  // SELLERS
  // ============================================================

  Future<Map<String, dynamic>> getSellerDashboard() async {
    final response = await _dio.get('/sellers/dashboard');
    return response.data;
  }

  Future<Map<String, dynamic>> getSellerProfile(String sellerId) async {
    final response = await _dio.get('/sellers/$sellerId');
    return response.data['seller'];
  }

  Future<Map<String, dynamic>> toggleFollow(String sellerId) async {
    final response = await _dio.post('/sellers/$sellerId/follow');
    return response.data;
  }

  // ============================================================
  // REVIEWS
  // ============================================================

  Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    await _dio.post('/buyers/review', data: {
      'order_id': orderId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }
  // ===== WALLET =====
  Future<Map<String, dynamic>> getWallet() async {
    final r = await _dio.get('/wallet');
    return r.data;
  }

  Future<Map<String, dynamic>> requestPayout({required double amountNaira}) async {
    final r = await _dio.post('/wallet/withdraw', data: {'amount_naira': amountNaira});
    return r.data;
  }

  Future<List<dynamic>> getBanks() async {
    final r = await _dio.get('/wallet/banks');
    return r.data['banks'];
  }

  Future<Map<String, dynamic>> verifyBankAccount({required String accountNumber, required String bankCode}) async {
    final r = await _dio.post('/wallet/verify-account', data: {'account_number': accountNumber, 'account_bank': bankCode});
    return r.data;
  }

  // ===== EXPLORE =====
  Future<List<dynamic>> getTrending() async {
    final r = await _dio.get('/explore/trending');
    return r.data['streams'];
  }

  Future<Map<String, dynamic>> searchStreams(String q) async {
    final r = await _dio.get('/explore/search', queryParameters: {'q': q});
    return r.data;
  }

  Future<Map<String, dynamic>> shareStream(String streamId) async {
    final r = await _dio.post('/explore/share/\$streamId');
    return r.data;
  }

  // ===== IMAGE UPLOAD =====
  Future<String> uploadProductImage(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final r = await _dio.post('/uploads/product-image', data: formData);
    return r.data['url'];
  }

  // ===== SHOP FEED =====
  Future<List<dynamic>> getFeedPosts({int page = 1}) async {
    final r = await _dio.get('/feed', queryParameters: {'page': page});
    return r.data['posts'];
  }

  Future<Map<String, dynamic>> createPost({
    required String mediaUrl,
    required String mediaType,
    String? caption,
    List<Map<String, dynamic>> products = const [],
  }) async {
    final r = await _dio.post('/feed', data: {
      'media_url': mediaUrl,
      'media_type': mediaType,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (products.isNotEmpty) 'products': products,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> likePost(String postId) async {
    final r = await _dio.post('/feed/\$postId/like');
    return r.data;
  }

  Future<List<dynamic>> getPostComments(String postId) async {
    final r = await _dio.get('/feed/\$postId/comments');
    return r.data['comments'];
  }

  Future<Map<String, dynamic>> addPostComment(String postId, String comment) async {
    final r = await _dio.post('/feed/\$postId/comment', data: {'comment': comment});
    return r.data;
  }

  Future<Map<String, dynamic>> buyFromPost({
    required String postId,
    required String productId,
    int quantity = 1,
    String? deliveryAddress,
    String? deliveryPhone,
  }) async {
    final r = await _dio.post('/feed/\$postId/buy', data: {
      'product_id': productId,
      'quantity': quantity,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryPhone != null) 'delivery_phone': deliveryPhone,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> sharePost(String postId) async {
    final r = await _dio.post('/explore/share/\$postId');
    return r.data;
  }

  Future<void> trackPostView(String postId) async {
    try { await _dio.patch('/feed/\$postId/view'); } catch (_) {}
  }

  Future<List<dynamic>> getSellerPosts(String sellerId) async {
    final r = await _dio.get('/feed/seller/\$sellerId');
    return r.data['posts'];
  }

  // ===== CHAT =====
  Future<List<dynamic>> getConversations() async {
    final r = await _dio.get('/chat/conversations');
    return r.data['conversations'];
  }

  Future<Map<String, dynamic>> startConversation(String sellerId) async {
    final r = await _dio.post('/chat/conversations', data: {'seller_id': sellerId});
    return r.data['conversation'];
  }

  Future<List<dynamic>> getMessages(String conversationId) async {
    final r = await _dio.get('/chat/conversations/\$conversationId/messages');
    return r.data['messages'];
  }

  Future<Map<String, dynamic>> sendMessage({required String conversationId, required String content, String type = 'text'}) async {
    final r = await _dio.post('/chat/conversations/\$conversationId/messages', data: {'content': content, 'message_type': type});
    return r.data['message'];
  }

  Future<Map<String, dynamic>> initiateCall({required String conversationId, required String callType}) async {
    final r = await _dio.post('/chat/calls/initiate', data: {'conversation_id': conversationId, 'call_type': callType});
    return r.data;
  }

  Future<void> updateCallStatus(String callId, String status) async {
    await _dio.patch('/chat/calls/\$callId', data: {'status': status});
  }

  // ===== FLASH SALES =====
  Future<List<dynamic>> getFlashSales() async {
    final r = await _dio.get('/features/flash-sales');
    return r.data['flash_sales'];
  }

  // ===== REFERRALS =====
  Future<Map<String, dynamic>> getReferralData() async {
    final r = await _dio.get('/features/referral');
    return r.data;
  }

  Future<void> applyReferralCode(String code) async {
    await _dio.post('/features/referral/apply', data: {'referral_code': code});
  }

  // ===== ADDRESSES =====
  Future<List<dynamic>> getAddresses() async {
    final r = await _dio.get('/features/addresses');
    return r.data['addresses'];
  }

  Future<void> addAddress({required String label, required String fullAddress, required String phone, bool isDefault = false}) async {
    await _dio.post('/features/addresses', data: {'label': label, 'full_address': fullAddress, 'phone': phone, 'is_default': isDefault});
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete('/features/addresses/\$id');
  }

  // ===== DISPUTES =====
  Future<List<dynamic>> getDisputes() async {
    final r = await _dio.get('/features/disputes');
    return r.data['disputes'];
  }

  Future<void> openDispute({required String orderId, required String reason, required String description}) async {
    await _dio.post('/features/disputes', data: {'order_id': orderId, 'reason': reason, 'description': description});
  }

  // ===== ANALYTICS =====
  Future<Map<String, dynamic>> getAnalytics() async {
    final r = await _dio.get('/features/analytics');
    return r.data;
  }

  // ===== GENERIC HTTP METHODS =====
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    final r = await _dio.get(path, queryParameters: params);
    return r.data;
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await _dio.patch(path, data: body);
    return r.data;
  }

  Future<dynamic> delete(String path) async {
    final r = await _dio.delete(path);
    return r.data;
  }

  // ===== SELLER PROFILE =====
  Future<Map<String, dynamic>> getSellerProfile(String sellerId) async {
    final r = await _dio.get('/auth/seller/\$sellerId');
    return r.data;
  }

  Future<List<dynamic>> getSellerReviews(String sellerId) async {
    final r = await _dio.get('/reviews/seller/\$sellerId/all');
    return r.data['reviews'];
  }

  Future<Map<String, dynamic>> updateSellerProfile({
    String? businessName, String? category, String? description,
    String? bankAccount, String? bankCode, String? accountName,
    String? pickupAddress,
  }) async {
    final r = await _dio.post('/auth/update-profile', data: {
      if (businessName != null) 'business_name': businessName,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (bankAccount != null) 'bank_account': bankAccount,
      if (bankCode != null) 'bank_code': bankCode,
      if (accountName != null) 'account_name': accountName,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> followSeller(String sellerId) async {
    final r = await _dio.post('/sellers/\$sellerId/follow');
    return r.data;
  }

  // ===== UNIFIED SEARCH =====
  Future<Map<String, dynamic>> searchAll(String q) async {
    final r = await _dio.get('/auth/search', queryParameters: {'q': q});
    return r.data;
  }

  // ===== ORDERS =====
  Future<List<dynamic>> getOrders() async {
    final r = await _dio.get('/orders');
    return r.data['orders'] ?? [];
  }

  // ===== PAYMENT VERIFY =====
  Future<Map<String, dynamic>> verifyPayment({String? transactionId, String? txRef}) async {
    final r = await _dio.post('/payments/verify', data: {
      if (transactionId != null) 'transaction_id': transactionId,
      if (txRef != null) 'tx_ref': txRef,
    });
    return r.data;
  }

}
