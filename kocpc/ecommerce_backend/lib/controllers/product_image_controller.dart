import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/database_service.dart';

// Ürün görselleri ile ilgili API işlemlerini yöneten controller sınıfı
class ProductImageController {

  // Ürüne ait yeni bir görsel ekleme işlemi
  static Future<Response> addProductImage(Request request) async {
    try {
      // İstek gövdesini string olarak oku
      final body = await request.readAsString();

      // JSON formatındaki gövdeyi Dart Map yapısına dönüştür
      final data = json.decode(body) as Map<String, dynamic>;

      // İstekten ürün ID ve görsel URL'si al
      final productId = data['product_id'] as int;
      final imageUrl = data['image_url'] as String;

      // Görsel URL'si boşsa 400 Bad Request döndür
      if (imageUrl.isEmpty) {
        return Response(
          400,
          body: json.encode({'error': 'Image URL is required'}),
          headers: {'content-type': 'application/json'}
        );
      }

      // Veritabanı bağlantısını al
      final db = await DatabaseService().database;

      // Öncelikle ürünün veritabanında var olup olmadığını kontrol et
      final product = db.select('SELECT id FROM Products WHERE id = ?', [productId]);

      // Ürün bulunamazsa 404 Not Found hatası döndür
      if (product.isEmpty) {
        return Response(
          404,
          body: json.encode({'error': 'Product not found'}),
          headers: {'content-type': 'application/json'}
        );
      }

      // Ürün varsa, ProductImages tablosuna yeni görsel kaydını ekle
      db.execute('''
        INSERT INTO ProductImages (product_id, image_url)
        VALUES (?, ?)
      ''', [productId, imageUrl]);

      // Başarılı ekleme sonrası 201 Created döndür
      return Response(
        201,
        body: json.encode({'message': 'Product image added successfully'}),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      // Hata varsa konsola yazdır ve 500 Internal Server Error dön
      print('Error in addProductImage: $e');
      return Response(
        500,
        body: json.encode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }

  // Belirli bir ürüne ait tüm görselleri alma işlemi
  static Future<Response> getProductImages(Request request) async {
    try {
      // URL parametresinden ürün ID'sini al (örnek: /products/123/images)
      final productId = int.parse(request.params['id']!);

      // Veritabanı bağlantısını al
      final db = await DatabaseService().database;

      // Ürüne ait tüm görselleri sorgula
      final images = db.select('SELECT * FROM ProductImages WHERE product_id = ?', [productId]);

      // Görselleri JSON formatında 200 OK ile döndür
      return Response(
        200,
        body: json.encode(images),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      // Hata durumunda log yaz ve 500 hata döndür
      print('Error in getProductImages: $e');
      return Response(
        500,
        body: json.encode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }

  // Ürün görselini ID'sine göre silme işlemi
  static Future<Response> deleteProductImage(Request request) async {
    try {
      // URL parametresinden görsel ID'sini al (örnek: /product-images/123)
      final imageId = int.parse(request.params['id']!);

      // Veritabanı bağlantısını al
      final db = await DatabaseService().database;

      // Görseli sil
      db.execute('DELETE FROM ProductImages WHERE id = ?', [imageId]);

      // Kaç satır etkilendiğini kontrol et
      final deleteCount = db.getUpdatedRows();

      // Eğer silinen satır yoksa, yani görsel bulunamadıysa 404 dön
      if (deleteCount == 0) {
        return Response(
          404,
          body: json.encode({'error': 'Product image not found'}),
          headers: {'content-type': 'application/json'}
        );
      }

      // Başarılı silme işlemi sonrası 200 OK dön
      return Response(
        200,
        body: json.encode({'message': 'Product image deleted successfully'}),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      // Hata varsa logla ve 500 Internal Server Error döndür
      print('Error in deleteProductImage: $e');
      return Response(
        500,
        body: json.encode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }
}
