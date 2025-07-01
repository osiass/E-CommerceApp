import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database.dart';

// 1. Giriş – Sınıf Tanımı ve Yapıcı (Constructor)
class AdminController {
  // Veritabanı işlemleri için bağlantı nesnesi
  final AppDatabase db;
  // Cevapların JSON formatında döndüğünü belirten header
  final _jsonHeaders = {'Content-Type': 'application/json'};

  AdminController(this.db);

  // 2. Admin Yetkilendirme Kontrolü
  Future<Map<String, dynamic>?> _getAuthorizedAdmin(Request request) async {
    // Kullanıcının kimliğini request.context'ten al
    final userId = request.context['userId'] as int?;
    if (userId == null) {
      print('AdminController: userId not found in context for authorization.');
      return null; 
    }

    try {
      // Veritabanında bu ID'ye sahip kullanıcının admin olup olmadığını kontrol et
      final users = await db.query(
        'SELECT id, name, email, is_admin FROM Users WHERE id = ? AND is_admin = 1',
        [userId],
      );
      if (users.isNotEmpty) {
        return users.first; // Admin kullanıcı bilgilerini döndür
      }
      print('AdminController: User $userId is not an admin or does not exist.');
      return null;
    } catch (e) {
      print('Error in _getAuthorizedAdmin: $e');
      return null;
    }
  }

  // 3. Router Oluşturma - Tüm admin API endpoint'leri burada tanımlanır
  Router get router {
    final router = Router();

    // 4. Yeni Ürün Ekleme (POST /products)
    router.post('/products', (Request request) async {
      // Admin yetkisi kontrolü
      final admin = await _getAuthorizedAdmin(request);
      if (admin == null) {
        return Response(403, body: jsonEncode({'error': 'Unauthorized'}), headers: _jsonHeaders);
      }

      try {
        // Gönderilen body içindeki bilgileri oku
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;

        // Gerekli alanları kontrol et
        final name = data['name'] as String?;
        final description = data['description'] as String?;
        final price = data['price'];
        final categoryId = data['category_id'];
        final stockQuantity = data['stock_quantity'];
        final imageUrl = data['image_url'] as String?;

        // Eksik veya geçersiz alanların kontrolü
        if (name == null || price == null || categoryId == null || stockQuantity == null) {
          return Response(400,
              body: jsonEncode({'error': 'Missing required fields: name, price, category_id, stock_quantity'}),
              headers: _jsonHeaders);
        }

        // Sayısal değerlerin kontrolü
        if (price is! num || categoryId is! num || stockQuantity is! num) {
          return Response(400,
              body: jsonEncode({'error': 'Price, category_id and stock_quantity must be numbers.'}),
              headers: _jsonHeaders);
        }

        // Veritabanına yeni ürün ekle
        await db.insert('Products', {
          'name': name,
          'description': description ?? '',
          'price': price,
          'category_id': categoryId,
          'stock_quantity': stockQuantity,
          'image_url': imageUrl,
        });
        return Response(201, body: jsonEncode({'message': 'Product added successfully'}), headers: _jsonHeaders);
      } catch (e) {
        print('Error adding product: $e');
        return Response(500,
            body: jsonEncode({'error': 'Failed to add product: ${e.toString()}'}), headers: _jsonHeaders);
      }
    });

    // 5. Ürün Güncelleme (PUT /products/<id>)
    router.put('/products/<id>', (Request request, String id) async {
      // Admin kontrolü
      final admin = await _getAuthorizedAdmin(request);
      if (admin == null) {
        return Response(403, body: jsonEncode({'error': 'Unauthorized'}), headers: _jsonHeaders);
      }

      try {
        // ID'nin geçerli sayı olup olmadığını kontrol et
        final productId = int.tryParse(id);
        if (productId == null) {
          return Response(400, body: jsonEncode({'error': 'Invalid product ID'}), headers: _jsonHeaders);
        }

        // Gövde içindeki verileri oku
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;

        // Güncellenmesi istenen alanları belirle
        final Map<String, dynamic> updates = {};
        if (data.containsKey('name')) updates['name'] = data['name'];
        if (data.containsKey('description')) updates['description'] = data['description'];
        if (data.containsKey('price')) {
          if (data['price'] is! num) return Response(400, body: jsonEncode({'error': 'Price must be a number.'}), headers: _jsonHeaders);
          updates['price'] = data['price'];
        }
        if (data.containsKey('category_id')) {
          if (data['category_id'] is! num) return Response(400, body: jsonEncode({'error': 'Category ID must be a number.'}), headers: _jsonHeaders);
          updates['category_id'] = data['category_id'];
        }
        if (data.containsKey('stock_quantity')) {
          if (data['stock_quantity'] is! num) return Response(400, body: jsonEncode({'error': 'Stock quantity must be a number.'}), headers: _jsonHeaders);
          updates['stock_quantity'] = data['stock_quantity'];
        }
        if (data.containsKey('image_url')) updates['image_url'] = data['image_url'];

        if (updates.isEmpty) {
          return Response(400, body: jsonEncode({'error': 'No fields to update'}), headers: _jsonHeaders);
        }
        
        // Veritabanında güncelleme yap
        await db.update('Products', updates, 'id = ?', [productId]);
        return Response(200, body: jsonEncode({'message': 'Product updated successfully'}), headers: _jsonHeaders);
      } catch (e) {
        print('Error updating product: $e');
        return Response(500,
            body: jsonEncode({'error': 'Failed to update product: ${e.toString()}'}), headers: _jsonHeaders);
      }
    });

    // 6. Ürün Silme (DELETE /products/<id>)
    router.delete('/products/<id>', (Request request, String id) async {
      // Admin kontrolü
      final admin = await _getAuthorizedAdmin(request);
      if (admin == null) {
        return Response(403, body: jsonEncode({'error': 'Unauthorized'}), headers: _jsonHeaders);
      }

      try {
        // Ürün ID'sini kontrol et
        final productId = int.tryParse(id);
        if (productId == null) {
          return Response(400, body: jsonEncode({'error': 'Invalid product ID'}), headers: _jsonHeaders);
        }

        // Veritabanından ürünü sil
        await db.delete('Products', 'id = ?', [productId]);
        return Response(200, body: jsonEncode({'message': 'Product deleted successfully'}), headers: _jsonHeaders);
      } catch (e) {
        print('Error deleting product: $e');
        // Dış bağımlılık kontrolü (foreign key constraint)
        if (e.toString().toLowerCase().contains('foreign key constraint failed')) {
          return Response(409, 
            body: jsonEncode({
              'error': 'Cannot delete product. It is referenced elsewhere (e.g., carts, orders).'
            }), 
            headers: _jsonHeaders
          );
        }
        return Response(500,
            body: jsonEncode({'error': 'Failed to delete product: ${e.toString()}'}), headers: _jsonHeaders);
      }
    });

    // 7. Kategori Silme (DELETE /categories/<categoryId>)
    router.delete('/categories/<categoryId>', (Request request) async {
      // Admin kontrolü
      final admin = await _getAuthorizedAdmin(request);
      if (admin == null) {
        return Response(403, body: jsonEncode({'error': 'Unauthorized'}), headers: _jsonHeaders);
      }

      try {
        final categoryId = int.parse(request.params['categoryId']!);
        
        // Kategoriye ait ürün var mı kontrol et
        final products = await db.query(
          'SELECT COUNT(*) as count FROM Products WHERE category_id = ?',
          [categoryId],
        );
        
        // Eğer ürün varsa önce ürünlerin silinmesi gerektiğini belirt
        if (products.first['count'] > 0) {
          return Response(400, 
            body: jsonEncode({'error': 'Bu kategoriye ait ürünler var. Önce ürünleri silmelisiniz.'}), 
            headers: _jsonHeaders
          );
        }

        // Kategoriyi veritabanından sil
        await db.execute('DELETE FROM Categories WHERE id = ?', [categoryId]);
        
        return Response.ok(
          jsonEncode({'message': 'Kategori başarıyla silindi'}),
          headers: _jsonHeaders
        );
      } catch (e) {
        return Response(500, 
          body: jsonEncode({'error': 'Kategori silinirken bir hata oluştu: ${e.toString()}'}), 
          headers: _jsonHeaders
        );
      }
    });

    return router;
  }
}