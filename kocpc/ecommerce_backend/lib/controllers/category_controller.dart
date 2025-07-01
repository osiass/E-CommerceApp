import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart'; // Router için gerekli
import '../database/database.dart'; // Veritabanı erişimi için

// CategoryController sınıfı: Ürün kategorileriyle ilgili işlemleri yönetir
class CategoryController {
  // Veritabanı bağlantısı nesnesi
  final AppDatabase db;

  // Yapıcı (Constructor): Veritabanı bağlantısını alır
  CategoryController(this.db);

  // Router getter: Kategori ile ilgili tüm endpointleri tanımlar
  Router get router {
    final router = Router();
    // Tüm kategorileri listeleme endpointi (GET /)
    router.get('/', listCategoriesHandler);
    // Belirli bir kategorinin detaylarını getirme endpointi (GET /<id>)
    router.get('/<id|[0-9]+>', getCategoryDetailsHandler);
    // Belirli bir kategoriye ait ürünleri getirme endpointi (GET /<id>/products)
    router.get('/<id|[0-9]+>/products', getProductsByCategoryIdHandler);
    return router;
  }

  // Tüm kategorileri listeleme handler fonksiyonu
  Future<Response> listCategoriesHandler(Request request) async {
    try {
      // Veritabanından tüm kategorileri çek
      final categories = await db.query('SELECT * FROM Categories');
      // Kategorileri JSON formatında yanıt olarak döndür
      return Response.ok(
        jsonEncode(categories),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('Error fetching categories: $e');
      // Hata durumunda sunucu hatası yanıtı döndür
      return Response.internalServerError(
        body: jsonEncode({'error': 'Kategoriler alınırken bir hata oluştu: ${e.toString()}'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Belirli bir kategorinin detaylarını getirme handler fonksiyonu
  Future<Response> getCategoryDetailsHandler(Request request) async {
    try {
      // İstekten kategori ID'sini al ve int'e çevir
      final categoryId = int.parse(request.params['id']!);
      // Veritabanından ilgili kategoriyi çek
      final categories = await db.query(
        'SELECT * FROM Categories WHERE id = ?',
        [categoryId],
      );
      
      // Kategori bulunamadıysa 404 yanıtı döndür
      if (categories.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Kategori bulunamadı'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // Kategori detaylarını JSON formatında yanıt olarak döndür
      return Response.ok(
        jsonEncode(categories.first),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      // Hata durumunda sunucu hatası yanıtı döndür
      return Response.internalServerError(
        body: jsonEncode({'error': 'Kategori detayları yüklenemedi: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Belirli bir kategoriye ait ürünleri getirme handler fonksiyonu
  Future<Response> getProductsByCategoryIdHandler(Request request) async {
    try {
      // İstekten kategori ID'sini al ve int'e çevir
      final categoryId = int.parse(request.params['id']!);
      // Veritabanından ilgili kategoriye ait ürünleri çek
      final products = await db.query(
        'SELECT * FROM Products WHERE category_id = ?',
        [categoryId],
      );
      
      // Ürünleri JSON formatında yanıt olarak döndür
      return Response.ok(
        jsonEncode(products),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      // Hata durumunda sunucu hatası yanıtı döndür
      return Response.internalServerError(
        body: jsonEncode({'error': 'Kategori ürünleri yüklenemedi: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}