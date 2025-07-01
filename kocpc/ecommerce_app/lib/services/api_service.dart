import 'dart:convert';  // JSON kodlama ve çözme için
import 'package:http/http.dart' as http;  // HTTP istekleri yapmak için
import 'dart:io';  // Platform bilgisi almak için

class ApiService {
  // Temel API URL'si; Android emulator için farklı, diğer platformlar için localhost
  static final String _baseUrl = Platform.isAndroid ? 'http://10.0.2.2:8080/api' : 'http://localhost:8080/api';
  static final String _authUrl = '$_baseUrl/auth';  // Kimlik doğrulama için temel URL

  static String? _token;  // Kullanıcı oturum token'ı (varsa)

  // Token'ı ayarla (login sonrası)
  static void setToken(String token) {
    _token = token;
  }

  // Token'ı temizle (logout için)
  static void clearToken() {
    _token = null;
  }

  // Kullanıcının giriş yapıp yapmadığını kontrol et
  static bool get isLoggedIn => _token != null;

  // API isteklerinde kullanılacak header'ları hazırla
  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};  // JSON içerik tipi belirt
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';  // Token varsa yetkilendirme header'ına ekle
    }
    return headers;
  }

  // Kullanıcı kayıt isteği gönderen metod
  static Future<http.Response> registerUser(String name, String email, String password, String phoneNumber, String address) async {
    final url = Uri.parse('$_authUrl/register');  // Kayıt endpoint'i
    final body = jsonEncode({  // Gönderilecek JSON body
      'name': name,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      'address': address,
    });
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},  // Kayıt isteğinde token gerekmez
      body: body,
    );
  }

  // Kullanıcı giriş isteği gönderen metod
  static Future<http.Response> loginUser(String email, String password) async {
    final url = Uri.parse('$_authUrl/login');  // Giriş endpoint'i
    print('[ApiService] Platform: ${Platform.operatingSystem}');  // Debug için platform bilgisi
    print('[ApiService] Base URL: $_baseUrl');  // Debug için base url
    print('[ApiService] Login URL: $url');  // Debug için login url
    final body = jsonEncode({
      'email': email,
      'password': password,
    });
    print('[ApiService] Login request body: $body');  // Gönderilen body'yi yazdır
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      print('[ApiService] Login response status: ${response.statusCode}');  // Gelen durumu yazdır
      print('[ApiService] Login response body: ${response.body}');  // Gelen cevabı yazdır
      return response;
    } catch (e) {
      print('[ApiService] Login error: $e');  // Hata varsa yazdır
      rethrow;  // Hatanın üst katmana geçmesini sağla
    }
  }

  // Tüm ürünleri listeleyen metod
  static Future<List<dynamic>> getProducts() async {
    final response = await http.get(Uri.parse('$_baseUrl/products'), headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);  // Başarılı ise JSON'u decode edip listeyi döndür
    } else {
      throw Exception('Ürünler yüklenemedi: ${response.statusCode} ${response.body}');  // Hata varsa exception fırlat
    }
  }

  // Belirli kategoriye ait ürünleri getiren metod
  static Future<List<dynamic>> getProductsByCategory(int categoryId) async {
    final response = await http.get(Uri.parse('$_baseUrl/categories/$categoryId/products'), headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Kategoriye ait ürünler yüklenemedi: ${response.statusCode} ${response.body}');
    }
  }

  // Ürün detaylarını getiren metod
  static Future<Map<String, dynamic>> getProductDetails(int productId) async {
    final response = await http.get(Uri.parse('$_baseUrl/products/$productId'), headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Ürün detayları yüklenemedi: ${response.statusCode} ${response.body}');
    }
  }

  // Tüm kategorileri listeleyen metod
  static Future<List<dynamic>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/categories'), headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Kategoriler yüklenemedi: ${response.statusCode} ${response.body}');
    }
  }

  // --- Admin için ürün ekleme API'si ---
  static Future<http.Response> addProduct(Map<String, dynamic> productData) async {
    final url = Uri.parse('$_baseUrl/admin/products');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(productData),  // Ürün verisini JSON olarak gönder
    );
  }

  // Admin için ürün güncelleme API'si
  static Future<http.Response> updateProduct(int productId, Map<String, dynamic> productData) async {
    final url = Uri.parse('$_baseUrl/admin/products/$productId');
    return await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode(productData),
    );
  }

  // Admin için ürün silme API'si
  static Future<http.Response> deleteProduct(int productId) async {
    final url = Uri.parse('$_baseUrl/admin/products/$productId');
    return await http.delete(
      url,
      headers: _getHeaders(),
    );
  }

  // --- Sepet işlemleri ---

  // Sepete ürün ekleme (varsayılan miktar 1)
  static Future<Map<String, dynamic>> addToCart(int productId, {int quantity = 1}) async {
    final url = Uri.parse('$_baseUrl/cart/add');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ?? 'Sepete eklenemedi';
      throw Exception('Sepete eklenemedi: $errorMessage - Kod: ${response.statusCode}');
    }
  }

  // Sepeti getiren metod
  static Future<Map<String, dynamic>> getCart() async {
    final url = Uri.parse('$_baseUrl/cart');
    final response = await http.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ?? 'Sepet yüklenemedi';
      throw Exception('Sepet yüklenemedi: $errorMessage - Kod: ${response.statusCode}');
    }
  }

  // Sepet ürün miktarını güncelleme
  static Future<Map<String, dynamic>> updateCartItem(int cartItemId, int quantity) async {
    final url = Uri.parse('$_baseUrl/cart/item/$cartItemId');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode({'quantity': quantity}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ?? 'Sepet güncellenemedi';
      throw Exception('Sepet güncellenemedi: $errorMessage - Kod: ${response.statusCode}');
    }
  }

  // Sepetten ürün silme
  static Future<Map<String, dynamic>> removeCartItem(int cartItemId) async {
    final url = Uri.parse('$_baseUrl/cart/item/$cartItemId');
    final response = await http.delete(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ?? 'Ürün sepetten silinemedi';
      throw Exception('Ürün sepetten silinemedi: $errorMessage - Kod: ${response.statusCode}');
    }
  }

  // --- Sipariş işlemleri ---

  // Sepetteki ürünlerle sipariş oluşturma (body boş, backend cart'tan alır)
  static Future<Map<String, dynamic>> createOrder() async {
    final url = Uri.parse('$_baseUrl/orders');
    final response = await http.post(
      url,
      headers: _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ?? 'Sipariş oluşturulamadı';
      throw Exception('Sipariş oluşturulamadı: $errorMessage - Kod: ${response.statusCode}');
    }
  }

  // --- Favoriler işlemleri ---

  // Ürünü favorilere ekle
  static Future<void> addFavorite(int productId, int userId) async {
    final url = Uri.parse('$_baseUrl/favorites');
    final response = await http.post(
      url,
      headers: _getHeaders()..addAll({'user_id': userId.toString()}),  // user_id header olarak gönderiliyor
      body: jsonEncode({'product_id': productId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Favoriye eklenemedi: ${response.body}');
    }
  }

  // Favorilerden ürün çıkar
  static Future<void> removeFavorite(int productId, int userId) async {
    final url = Uri.parse('$_baseUrl/favorites/$productId');
    final response = await http.delete(
      url,
      headers: _getHeaders()..addAll({'user_id': userId.toString()}),
    );
    if (response.statusCode != 200) {
      throw Exception('Favoriden çıkarılamadı: ${response.body}');
    }
  }

  // Kullanıcının favorilerini getir
  static Future<List<dynamic>> getFavorites(int userId) async {
    final url = Uri.parse('$_baseUrl/favorites');
    final response = await http.get(
      url,
      headers: _getHeaders()..addAll({'user_id': userId.toString()}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Favoriler yüklenemedi: ${response.body}');
    }
  }

  // --- Admin Kategori silme işlemi ---

  // Kategori silme isteği
  static Future<void> deleteCategory(int categoryId) async {
    final url = Uri.parse('$_baseUrl/admin/categories/$categoryId');
    final response = await http.delete(
      url,
      headers: _getHeaders(),
    );
    
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ?? 'Kategori silinemedi';
      throw Exception('$errorMessage - Kod: ${response.statusCode}');
    }
  }
}
