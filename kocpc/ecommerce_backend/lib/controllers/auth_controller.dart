import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:math';

// Kimlik doğrulama işlemlerini yöneten controller sınıfı
// Kullanıcı girişi, kayıt ve oturum yönetimi işlemlerini içerir
class AuthController {
  // Veritabanı bağlantısı
  final sqlite.Database _db;
  // JWT secret key (Gerçek uygulamada güvenli bir yerde saklanmalı)
  static const String _jwtSecret = 'your-secret-key';

  // Yapıcı (Constructor): Veritabanı bağlantısını alır
  AuthController(this._db);

  // Router getter: Tüm auth endpointlerini tanımlar
  Router get router {
    final router = Router();

    // Kullanıcı girişi endpoint'i
    router.post('/login', _loginHandler);
    // Kullanıcı kaydı endpoint'i
    router.post('/register', _registerHandler);
    // Kullanıcı bilgilerini getirme endpoint'i
    router.get('/me', _getCurrentUserHandler);

    return router;
  }

  // Kullanıcı girişi işleyicisi
  Future<Response> _loginHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Gerekli alanların kontrolü
      if (!data.containsKey('email') || !data.containsKey('password')) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Email ve şifre gereklidir'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final email = data['email'] as String;
      final password = data['password'] as String;

      // Kullanıcıyı veritabanında ara
      final result = _db.select(
        'SELECT * FROM users WHERE email = ?',
        [email],
      );

      if (result.isEmpty) {
        return Response.unauthorized(
          jsonEncode({'error': 'Geçersiz email veya şifre'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final user = result.first;
      final hashedPassword = _hashPassword(password);

      // Şifre kontrolü
      if (user['password_hash'] != hashedPassword) {
        return Response.unauthorized(
          jsonEncode({'error': 'Geçersiz email veya şifre'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // Başarılı giriş yanıtı
      final jwt = JWT(
        {
          'id': user['id'],
          'email': user['email'],
          'is_admin': user['is_admin'] == 1,
        },
      );
      final token = jwt.sign(SecretKey(_jwtSecret), expiresIn: Duration(days: 1));

      return Response.ok(
        jsonEncode({
          'message': 'Giriş başarılı',
          'user': {
            'id': user['id'],
            'email': user['email'],
            'name': user['name'],
            'is_admin': user['is_admin'] == 1,
          },
          'token': token,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Giriş işlemi başarısız: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Kullanıcı kaydı işleyicisi
  Future<Response> _registerHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Gerekli alanların kontrolü
      if (!data.containsKey('email') || !data.containsKey('password') || !data.containsKey('name')) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Email, şifre ve isim gereklidir'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final email = data['email'] as String;
      final password = data['password'] as String;
      final name = data['name'] as String;
      final phone = data['phone'] ?? '';
      final address = data['address'] ?? '';
      final now = DateTime.now().toIso8601String();

      // Email formatı kontrolü
      if (!_isValidEmail(email)) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Geçersiz email formatı'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // Email kullanımda mı kontrolü
      final existingUser = _db.select(
        'SELECT * FROM users WHERE email = ?',
        [email],
      );

      if (existingUser.isNotEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Bu email adresi zaten kullanımda'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // Şifreyi hashle
      final hashedPassword = _hashPassword(password);

      // Yeni kullanıcıyı veritabanına ekle
      _db.execute(
        'INSERT INTO users (name, email, password_hash, phone_number, address, is_admin, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [name, email, hashedPassword, phone, address, 0, now],
      );

      return Response.ok(
        jsonEncode({'message': 'Kayıt başarılı'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Kayıt işlemi başarısız: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Mevcut kullanıcı bilgilerini getiren işleyici
  Future<Response> _getCurrentUserHandler(Request request) async {
    try {
      // Authorization header'ından kullanıcı ID'sini al
      final userId = request.headers['user_id'];
      if (userId == null) {
        return Response.unauthorized(
          jsonEncode({'error': 'Yetkilendirme gerekli'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // Kullanıcı bilgilerini veritabanından getir
      final result = _db.select(
        'SELECT id, email, name, is_admin FROM users WHERE id = ?',
        [userId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Kullanıcı bulunamadı'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final user = result.first;
      return Response.ok(
        jsonEncode({
          'id': user['id'],
          'email': user['email'],
          'name': user['name'],
          'is_admin': user['is_admin'] == 1,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Kullanıcı bilgileri alınamadı: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Şifre hashleme yardımcı fonksiyonu
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Email formatı kontrolü yardımcı fonksiyonu
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
} 