import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// FavoriteController sınıfı: Kullanıcı favori ürünleriyle ilgili işlemleri yönetir
class FavoriteController {
  // Veritabanı bağlantısı nesnesi
  final sqlite.Database db;
  // Yapıcı (Constructor): Veritabanı bağlantısını alır
  FavoriteController(this.db);

  // Router getter: Favori ile ilgili tüm endpointleri tanımlar
  Router get router {
    final router = Router();

    // Favoriye ürün ekleme endpointi (POST /)
    router.post('/', (Request request) async {
      try {
        // İstek gövdesini oku ve JSON olarak parse et
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        // Kullanıcı ID'sini header veya body'den al
        // NOT: Normalde userId AuthMiddleware tarafından context'e eklenmeli ve buradan alınmalı.
        final userId = int.tryParse(request.headers['user_id'] ?? '') ?? data['user_id'];
        final productId = data['product_id'];
        // Gerekli alanların kontrolü
        if (userId == null || productId == null) {
          return Response.badRequest(body: jsonEncode({'error': 'user_id ve product_id gerekli'}), headers: {'content-type': 'application/json'});
        }
        // Favorilere ürünü ekle (aynısı varsa ekleme - INSERT OR IGNORE)
        db.execute('INSERT OR IGNORE INTO Favorites (user_id, product_id) VALUES (?, ?)', [userId, productId]);
        // Başarılı yanıt döndür
        return Response.ok(jsonEncode({'message': 'Favoriye eklendi'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        print('Error adding favorite: $e');
        // Hata durumunda sunucu hatası yanıtı döndür
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // Favoriden ürün çıkarma endpointi (DELETE /<productId>)
    router.delete('/<productId>', (Request request, String productId) async {
      try {
        // Kullanıcı ID'sini header'dan al
        // NOT: Normalde userId AuthMiddleware tarafından context'e eklenmeli ve buradan alınmalı.
        final userId = int.tryParse(request.headers['user_id'] ?? '');
        // Gerekli alanın kontrolü
        if (userId == null) {
          return Response.badRequest(body: jsonEncode({'error': 'user_id gerekli'}), headers: {'content-type': 'application/json'});
        }
        // Favorilerden ürünü sil
        db.execute('DELETE FROM Favorites WHERE user_id = ? AND product_id = ?', [userId, productId]);
        // Başarılı yanıt döndür
        return Response.ok(jsonEncode({'message': 'Favoriden çıkarıldı'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        print('Error removing favorite: $e');
        // Hata durumunda sunucu hatası yanıtı döndür
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // Kullanıcının favori ürünlerini getirme endpointi (GET /)
    router.get('/', (Request request) async {
      try {
        // Kullanıcı ID'sini header'dan al
        // NOT: Normalde userId AuthMiddleware tarafından context'e eklenmeli ve buradan alınmalı.
        final userId = int.tryParse(request.headers['user_id'] ?? '');
        // Gerekli alanın kontrolü
        if (userId == null) {
          return Response.badRequest(body: jsonEncode({'error': 'user_id gerekli'}), headers: {'content-type': 'application/json'});
        }
        // Kullanıcının favori ürünlerini Products tablosuyla JOIN yaparak getir
        final favorites = db.select('''
          SELECT p.* FROM Products p
          INNER JOIN Favorites f ON f.product_id = p.id
          WHERE f.user_id = ?
        ''', [userId]);
        // Favori ürünleri JSON formatında yanıt olarak döndür
        return Response.ok(jsonEncode(favorites), headers: {'content-type': 'application/json'});
      } catch (e) {
        print('Error fetching favorites: $e');
        // Hata durumunda sunucu hatası yanıtı döndür
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    return router;
  }
} 