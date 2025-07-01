import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:convert';

// Yetkilendirme (Authentication) middleware'i
class AuthMiddleware {
  
  // Bu metod, verilen handler'ı alır ve onu JWT doğrulaması yapan bir middleware ile sarar
  static Handler requireAuth(Handler handler) {
    // Gelen isteği işleyen yeni handler döner
    return (Request request) async {
      // İstek geldiğinde log basar (HTTP metodu ve URL yolu)
      print('[AuthMiddleware] İstek geldi: ${request.method} ${request.url.path}');

      // Authorization header'ını al (örnek: "Bearer <token>")
      final authHeader = request.headers['authorization'];

      // İstek URL'sini tekrar logla
      print('[AuthMiddleware] Path: ${request.url.path}');

      // Eğer authorization header yoksa veya Bearer ile başlamıyorsa hata döndür
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        print('[AuthMiddleware] Eksik veya hatalı token: ${request.url.path}');
        return Response.forbidden(
          jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'content-type': 'application/json'}
        );
      }

      // "Bearer " kısmını çıkar ve tokenı elde et
      final token = authHeader.substring(7);
      print('[AuthMiddleware] Token ayrıştırıldı: $token');

      try {
        // Token'ı doğrula (imzayı kontrol et)
        // TODO: 'your-secret-key' kısmını ortam değişkeni (env variable) olarak saklamak daha güvenli olur
        final jwt = JWT.verify(token, SecretKey('your-secret-key'));

        // Token içinden userId değerini al (int olarak)
        final userId = jwt.payload['id'] as int;
        print('[AuthMiddleware] Token doğrulandı, userId: $userId');

        // Orijinal isteği, userId bilgisini context içine ekleyerek değiştir
        final updatedRequest = request.change(context: {'userId': userId});

        // Güncellenmiş istekle orijinal handler'ı çağır (işlemi devam ettir)
        return handler(updatedRequest);
      } catch (e) {
        // Token doğrulama başarısızsa logla ve 401 Unauthorized dön
        print('[AuthMiddleware] Token doğrulama başarısız: ${e.toString()}');
        return Response.unauthorized(
          jsonEncode({'error': 'Invalid token'}),
          headers: {'content-type': 'application/json'}
        );
      }
    };
  }
}
