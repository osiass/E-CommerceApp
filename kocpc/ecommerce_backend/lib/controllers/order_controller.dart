import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart'; // Router için gerekli (yorumlansada burada kalmalı)
import '../services/database_service.dart'; // DatabaseService import edildi (static handlerlar için gerekli)
import 'package:sqlite3/sqlite3.dart' as sqlite; // Veritabanı erişimi için

// OrderController sınıfı: Kullanıcı sipariş işlemlerini yönetir
class OrderController {
  // Veritabanı bağlantısı nesnesi
  final sqlite.Database _db;

  // Yapıcı (Constructor): Veritabanı bağlantısını alır
  OrderController(this._db);


  Future<Response> createOrderHandler(Request request) async {
    try {
      // Kullanıcı kimliğini request context'ten al (AuthMiddleware tarafından ayarlanır)
      final userId = request.context['userId'] as int?;
      // Kullanıcı yetkili değilse 403 Forbidden yanıtı döndür
      if (userId == null) {
        return Response.forbidden(jsonEncode({'error': 'User not authenticated'}), headers: {'content-type': 'application/json'});
      }

      // Kullanıcının mevcut sepetindeki ürünleri veritabanından çek
      final cartResult = _db.select('''
        SELECT
            ci.id AS cart_item_id,
            ci.product_id,
            ci.quantity,
            p.price,
            p.stock_quantity
        FROM CartItems ci
        JOIN Products p ON ci.product_id = p.id
        WHERE ci.user_id = ?
      ''', [userId]);

      // Sepet boşsa hata yanıtı döndür
      if (cartResult.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Sepetiniz boş'}), headers: {'content-type': 'application/json'});
      }

      // Sipariş oluşturmadan önce ürünlerin stok miktarını kontrol et
      for (final item in cartResult) {
        if (item['quantity'] > item['stock_quantity']) {
          return Response.badRequest(body: jsonEncode({'error': 'Stok yetersiz: ${item['product_id']}'}), headers: {'content-type': 'application/json'});
        }
      }

      // Toplam sipariş tutarını hesapla ve kullanıcı adresini çek
      double totalAmount = 0;
      final orderItems = <Map<String, dynamic>>[];

      for (final item in cartResult) {
        // Ürün fiyatını num veya string olarak alıp double'a çevir
        final price = item['price'] is String ? double.tryParse(item['price']) ?? 0.0 : (item['price'] as num).toDouble();
        final quantity = item['quantity'] as int;
        totalAmount += price * quantity;
        // Sipariş öğesi detaylarını kaydet (satın alma anındaki fiyat dahil)
        orderItems.add({
          'product_id': item['product_id'],
          'quantity': quantity,
          'price_at_purchase': price, 
        });
      }
      
      // Kullanıcı adresini Users tablosundan çek
      final userResult = _db.select('SELECT address FROM Users WHERE id = ?', [userId]);
      final deliveryAddress = userResult.isNotEmpty ? userResult.first['address'] : '';

      // Orders tablosuna yeni sipariş kaydı ekle
      _db.execute('''
        INSERT INTO Orders (user_id, order_date, total_amount, delivery_address, status)
        VALUES (?, CURRENT_TIMESTAMP, ?, ?, ?)
      ''', [userId, totalAmount, deliveryAddress, 'Pending']); // Başlangıç statüsü 'Pending'
      
      // Yeni oluşturulan siparişin ID'sini al (SQLite'da last_insert_rowid() kullanılır)
       final orderIdResult = _db.select('SELECT last_insert_rowid()');
       final orderId = orderIdResult.first[0] as int;

      // OrderItems tablosuna sepet öğelerini ekle ve ürün stoklarını güncelle
      for (final item in orderItems) {
        final itemId = item['product_id'];
        final itemQuantity = item['quantity'];
        final itemPrice = item['price_at_purchase'];
        // OrderItems tablosuna sipariş öğesini ekle
        _db.execute('''
          INSERT INTO OrderItems (order_id, product_id, quantity, price_at_purchase)
          VALUES (?, ?, ?, ?)
        ''', [orderId, itemId, itemQuantity, itemPrice]);

        // Ürün stok miktarını azalt
        _db.execute('UPDATE Products SET stock_quantity = stock_quantity - ? WHERE id = ?', [itemQuantity, itemId]);
      }

      // Sipariş oluştuktan sonra kullanıcının sepetini temizle
      _db.execute('DELETE FROM CartItems WHERE user_id = ?', [userId]);

      // Başarılı sipariş oluşturma yanıtı döndür
      return Response.ok(jsonEncode({'message': 'Sipariş başarıyla oluşturuldu', 'order_id': orderId}), headers: {'content-type': 'application/json'});

    } catch (e) {
      print('Error creating order: $e');
      // Hata durumunda sunucu hatası yanıtı döndür
      return Response.internalServerError(body: jsonEncode({'error': 'Sipariş oluşturulurken bir hata oluştu: ${e.toString()}'}), headers: {'content-type': 'application/json'});
    }
  }

  // Kullanıcının tüm siparişlerini getirme handler fonksiyonu (Henüz aktif route'u yok)
  // DİKKAT: Bu handler static tanımlanmış ve DatabaseService() üzerinden db bağlantısı alıyor.
  // Bu, OrderController sınıfının constructor ile aldığı _db bağlantısını kullanmıyor.
  // Mimaride tutarsızlık veya potansiyel sorunlara yol açabilir.
  static Future<Response> getUserOrders(Request request) async {
    try {
      // Kullanıcı ID'sini context'ten al
      final userId = request.context['userId'] as int; // NOTE: This handler is currently static, needs review if it's mounted correctly.
      // Veritabanı bağlantısını al (DatabaseService üzerinden - static method kullanımı)
      // NOT: Bu handler static olduğu için db bağlantısını bu şekilde alıyor, sınıf yapısına uymuyor.
      final db = await DatabaseService().database;
      
      // Kullanıcının siparişlerini OrderItems tablosuyla JOIN yaparak getir ve öğe sayısını hesapla
      final orders = db.select('''
        SELECT o.*, 
               COUNT(oi.id) as item_count
        FROM Orders o
        LEFT JOIN OrderItems oi ON o.id = oi.order_id
        WHERE o.user_id = ?
        GROUP BY o.id
        ORDER BY o.order_date DESC
      ''', [userId]);

      // Siparişleri JSON formatında yanıt olarak döndür
      return Response(200, 
        body: json.encode(orders),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      // Hata durumunda sunucu hatası yanıtı döndür
      return Response(500, 
        body: json.encode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }

  // Belirli bir siparişin detaylarını getirme handler fonksiyonu (Henüz aktif route'u yok)
  // DİKKAT: Bu handler static tanımlanmış ve DatabaseService() üzerinden db bağlantısı alıyor.
  // Bu, OrderController sınıfının constructor ile aldığı _db bağlantısını kullanmıyor.
  // Mimaride tutarsızlık veya potansiyel sorunlara yol açabilir.
  static Future<Response> getOrderById(Request request) async {
    try {
      // Kullanıcı ID'sini context'ten al
      final userId = request.context['userId'] as int; // NOTE: This handler is currently static, needs review if it's mounted correctly.
      // Sipariş ID'sini request params'tan al
      final orderId = int.parse(request.params['id']!);
      
      // Veritabanı bağlantısını al (DatabaseService üzerinden - static method kullanımı)
      // NOT: Bu handler static olduğu için db bağlantısını bu şekilde alıyor, sınıf yapısına uymuyor.
      final db = await DatabaseService().database;

      // Sipariş detaylarını veritabanından çek
      final order = db.select('''
        SELECT * FROM Orders 
        WHERE id = ? AND user_id = ?
      ''', [orderId, userId]);

      // Sipariş bulunamadıysa 404 yanıtı döndür
      if (order.isEmpty) {
        return Response(404, 
          body: json.encode({'error': 'Order not found'}),
          headers: {'content-type': 'application/json'}
        );
      }

      // Sipariş öğelerini ürün detaylarıyla birlikte çek
      final orderItems = db.select('''
        SELECT oi.*, p.name, p.image_url
        FROM OrderItems oi
        JOIN Products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
      ''', [orderId]);

      // Sipariş detayları ve öğelerini içeren bir map oluştur
      final orderDetails = {
        ...order.first,
        'items': orderItems
      };

      // Sipariş detaylarını JSON formatında yanıt olarak döndür
      return Response(200, 
        body: json.encode(orderDetails),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      // Hata durumunda sunucu hatası yanıtı döndür
      return Response(500, 
        body: json.encode({'error': 'Internal server error'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }
}