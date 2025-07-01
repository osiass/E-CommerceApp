import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite; // SQLite veritabanı kütüphanesi


// CartController sınıfı: Kullanıcı sepet işlemlerini yönetir
class CartController {
  // Veritabanı bağlantısı
  final sqlite.Database _db;

  // Yapıcı (Constructor): Veritabanı bağlantısını alır
  CartController(this._db);

  // Sepete ürün ekleme endpoint'i (POST /cart/add)
  Future<Response> addToCart(Request request) async {
    // Kullanıcı kimliğini request context'ten al
    final userId = request.context['userId'] as int?;
    if (userId == null) {
      return Response.unauthorized(jsonEncode({'error': 'Not authenticated'}), headers: {'content-type': 'application/json'});
    }

    // İstek gövdesini oku
    final body = await request.readAsString();
    if (body.isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'Missing request body'}), headers: {'content-type': 'application/json'});
    }

    // JSON payload'u parse et
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(body);
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'error': 'Invalid JSON format'}), headers: {'content-type': 'application/json'});
    }

    // productId ve quantity değerlerini al
    final productId = payload['product_id'] as int?;
    final quantity = payload['quantity'] as int? ?? 1;

    // Gerekli alanların kontrolü
    if (productId == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Missing product_id'}), headers: {'content-type': 'application/json'});
    }
    if (quantity <= 0) {
      return Response.badRequest(body: jsonEncode({'error': 'Quantity must be positive'}), headers: {'content-type': 'application/json'});
    }

    try {
      // Ürünün stok durumunu kontrol et
      final productCheck = _db.select('SELECT stock_quantity FROM Products WHERE id = ?', [productId]);
      if (productCheck.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}), headers: {'content-type': 'application/json'});
      }
      final stockQuantity = productCheck.first['stock_quantity'] as int;

      // Sepette ürün var mı kontrol et
      final existingCartItem = _db.select(
        'SELECT id, quantity FROM CartItems WHERE user_id = ? AND product_id = ?',
        [userId, productId],
      );

      int finalQuantity;
      if (existingCartItem.isNotEmpty) {
        // Ürün sepette varsa miktarı güncelle
        final currentQuantity = existingCartItem.first['quantity'] as int;
        final cartItemId = existingCartItem.first['id'] as int;
        finalQuantity = currentQuantity + quantity;
        
        // Stok kontrolü
        if (finalQuantity > stockQuantity) {
            return Response.badRequest(body: jsonEncode({'error': 'Cannot add more than available stock. Current in cart: $currentQuantity, Requested to add: $quantity, Stock: $stockQuantity'}), headers: {'content-type': 'application/json'});
        }
        
        _db.execute(
          'UPDATE CartItems SET quantity = ? WHERE id = ?',
          [finalQuantity, cartItemId],
        );
      } else {
        // Ürün sepette yoksa yeni kayıt ekle
        finalQuantity = quantity;
         // Stok kontrolü
         if (finalQuantity > stockQuantity) {
            return Response.badRequest(body: jsonEncode({'error': 'Cannot add more than available stock. Stock: $stockQuantity'}), headers: {'content-type': 'application/json'});
        }
        _db.execute(
          'INSERT INTO CartItems (user_id, product_id, quantity) VALUES (?, ?, ?)',
          [userId, productId, finalQuantity],
        );
      }
      // Güncellenmiş veya yeni eklenen sepet öğesinin ID'sini al
      final insertedItemId = existingCartItem.isNotEmpty ? existingCartItem.first['id'] as int : _db.lastInsertRowId;
      // Başarılı yanıt döndür
      return Response.ok(jsonEncode({'message': 'Product added/updated in cart', 'cart_item_id': insertedItemId, 'product_id': productId, 'new_quantity': finalQuantity}), headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Error adding to cart: $e');
      // Hataları işle
      return Response.internalServerError(body: jsonEncode({'error': 'Error adding to cart: ${e.toString()}'}), headers: {'content-type': 'application/json'});
    }
  }

  // Sepet içeriğini getirme endpoint'i (GET /cart)
  Future<Response> getCartItems(Request request) async {
    // Kullanıcı kimliğini request context'ten al
    final userId = request.context['userId'] as int?;
    if (userId == null) {
      return Response.unauthorized(jsonEncode({'error': 'Not authenticated'}), headers: {'content-type': 'application/json'});
    }

    try {
      // Kullanıcının sepetindeki ürünleri ve detaylarını getir
      final cartItemsResult = _db.select('''
        SELECT
          ci.id as cart_item_id,
          ci.product_id,
          ci.quantity,
          p.name,
          p.price,
          p.image_url,
          p.stock_quantity
        FROM CartItems ci
        JOIN Products p ON ci.product_id = p.id
        WHERE ci.user_id = ?
      ''', [userId]);

      // Sonuçları bir listeye dönüştür
      final List<Map<String, dynamic>> items = [];
        for (final row in cartItemsResult) {
            items.add({
                'cart_item_id': row['cart_item_id'],
                'product_id': row['product_id'],
                'quantity': row['quantity'],
                'name': row['name'],
                'price': row['price'],
                'image_url': row['image_url'],
                'stock_quantity': row['stock_quantity'],
            });
        }

      // Toplam sepet tutarını hesapla
      final totalAmount = items.fold<double>(0.0, (sum, item) {
        return sum + (item['price'] as num) * (item['quantity'] as int);
      });

      // Sepet içeriği ve toplam tutar ile yanıt döndür
      return Response.ok(jsonEncode({
        'items': items,
        'total_amount': totalAmount,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Error fetching cart items: $e');
      // Hataları işle
      return Response.internalServerError(body: jsonEncode({'error': 'Error fetching cart items: ${e.toString()}'}), headers: {'content-type': 'application/json'});
    }
  }

  // Sepet öğesini güncelleme endpoint'i (PUT /cart/item/<cartItemId>)
  Future<Response> updateCartItem(Request request, String cartItemIdStr) async {
    // Kullanıcı kimliğini request context'ten al
    final userId = request.context['userId'] as int?;
    if (userId == null) {
      return Response.unauthorized(jsonEncode({'error': 'Not authenticated'}), headers: {'content-type': 'application/json'});
    }

    // cartItemId parametresini parse et
    final cartItemId = int.tryParse(cartItemIdStr);
    if (cartItemId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid cart_item_id format'}), headers: {'content-type': 'application/json'});
    }

    // İstek gövdesini oku
    final body = await request.readAsString();
    if (body.isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'Missing request body'}), headers: {'content-type': 'application/json'});
    }
    // JSON payload'u parse et
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(body);
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'error': 'Invalid JSON format'}), headers: {'content-type': 'application/json'});
    }

    // quantity değerini al
    final quantity = payload['quantity'] as int?;
    if (quantity == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing quantity'}), headers: {'content-type': 'application/json'});
    }
    
    // Eğer miktar 0 ise, ürünü sepetten sil (removeCartItem fonksiyonunu çağır)
    if (quantity == 0) {
        return removeCartItem(request, cartItemIdStr, isInternalCall: true);
    }

    // Miktarın negatif olup olmadığını kontrol et
    if (quantity < 0) {
        return Response.badRequest(body: jsonEncode({'error': 'Quantity cannot be negative.'}), headers: {'content-type': 'application/json'});
    }


    try {
        // Güncellenmek istenen sepet öğesinin kullanıcıya ait olup olmadığını ve ürününü kontrol et
        final itemCheck = _db.select('SELECT product_id FROM CartItems WHERE id = ? AND user_id = ?', [cartItemId, userId]);
        if (itemCheck.isEmpty) {
            return Response.notFound(jsonEncode({'error': 'Cart item not found or does not belong to user'}), headers: {'content-type': 'application/json'});
        }
        final productId = itemCheck.first['product_id'];

        // Ürünün stok miktarını kontrol et
        final productStockCheck = _db.select('SELECT stock_quantity FROM Products WHERE id = ?', [productId]);
         if (productStockCheck.isEmpty) { 
            return Response.internalServerError(body: jsonEncode({'error':'Product associated with cart item not found'}), headers: {'content-type': 'application/json'});
        }
        final stockQuantity = productStockCheck.first['stock_quantity'] as int;

        // Güncellenmek istenen miktarın stok miktarından fazla olup olmadığını kontrol et
        if (quantity > stockQuantity) {
            return Response.badRequest(body: jsonEncode({'error': 'Cannot update quantity beyond available stock. Stock: $stockQuantity'}), headers: {'content-type': 'application/json'});
        }

        // Sepet öğesinin miktarını güncelle
        _db.execute('UPDATE CartItems SET quantity = ? WHERE id = ? AND user_id = ?', [quantity, cartItemId, userId]);
        // Başarılı yanıt döndür
        return Response.ok(jsonEncode({'message': 'Cart item updated', 'cart_item_id': cartItemId, 'new_quantity': quantity}), headers: {'content-type': 'application/json'});
    } catch (e) {
        print('Error updating cart item: $e');
        // Hataları işle
        return Response.internalServerError(body: jsonEncode({'error': 'Error updating cart item: ${e.toString()}'}), headers: {'content-type': 'application/json'});
    }
  }

  // Sepet öğesini silme endpoint'i (DELETE /cart/item/<cartItemId>)
  // isInternalCall: Eğer başka bir fonksiyondan çağrılıyorsa (örn: updateQuantity=0) kullanılır
  Future<Response> removeCartItem(Request request, String cartItemIdStr, {bool isInternalCall = false}) async {
    // Kullanıcı kimliğini request context'ten al (dahili çağrı değilse kontrol et)
    final userId = request.context['userId'] as int?;
     if (!isInternalCall && userId == null) { 
      return Response.unauthorized(jsonEncode({'error': 'Not authenticated'}), headers: {'content-type': 'application/json'});
    }
    // cartItemId parametresini parse et
    final cartItemId = int.tryParse(cartItemIdStr);
     if (cartItemId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid cart_item_id format'}), headers: {'content-type': 'application/json'});
    }

    try {
        // Silinmek istenen sepet öğesinin kullanıcıya ait olup olmadığını kontrol et
        final itemCheck = _db.select('SELECT id FROM CartItems WHERE id = ? AND user_id = ?', [cartItemId, userId]);
        if (itemCheck.isEmpty) {
            return Response.notFound(jsonEncode({'error': 'Cart item not found or does not belong to user'}), headers: {'content-type': 'application/json'});
        }

        // Sepet öğesini veritabanından sil
        _db.execute('DELETE FROM CartItems WHERE id = ? AND user_id = ?', [cartItemId, userId]);
        // Başarılı yanıt döndür
        return Response.ok(jsonEncode({'message': 'Cart item removed', 'cart_item_id': cartItemId}), headers: {'content-type': 'application/json'});
    } catch (e) {
        print('Error removing cart item: $e');
        // Hataları işle
        return Response.internalServerError(body: jsonEncode({'error': 'Error removing cart item: ${e.toString()}'}), headers: {'content-type': 'application/json'});
    }
  }
} 