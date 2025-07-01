import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database.dart';

// ProductController sınıfı: Ürün yönetimi ve işlemleri için API endpoint'lerini sağlar
class ProductController {
  // Veritabanı bağlantısı
  final AppDatabase db;
  // Ürün resimlerinin yükleneceği klasör yolu
  final String uploadDir = 'uploads/products';

  // Yapıcı (Constructor): Veritabanı bağlantısını alır ve uploads klasörünü oluşturur
  ProductController(this.db) {
    // Uploads klasörünü oluştur (yoksa)
    Directory(uploadDir).create(recursive: true);
  }

  // Router getter: Tüm ürün API endpoint'lerini tanımlar
  Router get router {
    final router = Router();

    // GET / - Tüm ürünleri listeler
    // Kategorilerle birlikte ürün bilgilerini getirir
    router.get('/', (Request request) async {
      try {
        // Ürünleri kategorileriyle birlikte çek
        final products = await db.query('''
          SELECT p.*, c.name as category_name 
          FROM Products p
          LEFT JOIN Categories c ON p.category_id = c.id
          ORDER BY p.created_at DESC
        ''');

        return Response.ok(
          jsonEncode(products),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // GET /category/<categoryId> - Belirli bir kategorideki ürünleri listeler
    router.get('/category/<categoryId>', (Request request, String categoryId) async {
      try {
        // Kategoriye göre ürünleri filtrele
        final products = await db.query('''
          SELECT p.*, c.name as category_name 
          FROM Products p
          LEFT JOIN Categories c ON p.category_id = c.id
          WHERE p.category_id = ?
          ORDER BY p.created_at DESC
        ''', [categoryId]);

        return Response.ok(
          jsonEncode(products),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // GET /<productId> - Belirli bir ürünün detaylarını getirir
    router.get('/<productId>', (Request request, String productId) async {
      try {
        // Ürün detaylarını ve kategorisini çek
        final products = await db.query('''
          SELECT p.*, c.name as category_name 
          FROM Products p
          LEFT JOIN Categories c ON p.category_id = c.id
          WHERE p.id = ?
        ''', [productId]);

        if (products.isEmpty) {
          return Response.notFound(
            jsonEncode({'error': 'Ürün bulunamadı'}),
            headers: {'content-type': 'application/json'},
          );
        }

        final productData = Map<String, dynamic>.from(products.first);

        // Ürünün özelliklerini çek
        final features = await db.query('''
          SELECT feature_name, feature_value
          FROM ProductFeatures
          WHERE product_id = ?
        ''', [productId]);

        productData['features'] = features; // Özellikleri ürün verisine ekle

        return Response.ok(
          jsonEncode(productData),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // POST /<productId>/image - Ürün resmi yükler
    router.post('/<productId>/image', (Request request, String productId) async {
      try {
        // Ürünün var olduğunu kontrol et
        final product = await _getProductById(productId);
        if (product == null) {
          return Response.notFound('Ürün bulunamadı');
        }

        // Form verilerini oku
        final formData = await request.read().expand((chunk) => chunk).toList();
        if (formData.isEmpty) {
          return Response.badRequest(body: 'Resim dosyası bulunamadı');
        }

        // Benzersiz dosya adı oluştur
        final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(request.headers['content-type'] ?? '.jpg')}';
        final filePath = path.join(uploadDir, fileName);
        
        // Resmi kaydet
        await File(filePath).writeAsBytes(formData);
        
        // Veritabanında resim URL'sini güncelle
        await db.execute(
          'UPDATE Products SET image_url = ? WHERE id = ?',
          ['/uploads/products/$fileName', productId]
        );

        return Response.ok('Resim başarıyla yüklendi');
      } catch (e) {
        print('Resim yükleme hatası: $e');
        return Response.internalServerError(body: 'Resim yüklenirken bir hata oluştu');
      }
    });

    // GET /<productId>/image - Ürün resmini getirir
    router.get('/<productId>/image', (Request request, String productId) async {
      try {
        // Ürünü ve resim URL'sini kontrol et
        final product = await _getProductById(productId);
        if (product == null || product['image_url'] == null) {
          return Response.notFound('Ürün resmi bulunamadı');
        }

        // Resim dosyasının yolunu oluştur
        final imagePath = path.join(Directory.current.path, product['image_url'].toString().substring(1));
        final file = File(imagePath);
        
        // Dosyanın var olduğunu kontrol et
        if (!await file.exists()) {
          return Response.notFound('Resim dosyası bulunamadı');
        }

        // Resmi döndür
        return Response.ok(
          file.openRead(),
          headers: {'content-type': 'image/jpeg'}
        );
      } catch (e) {
        print('Resim getirme hatası: $e');
        return Response.internalServerError(body: 'Resim getirilirken bir hata oluştu');
      }
    });

    return router;
  }

  // Yardımcı metod: ID'ye göre ürün getirir
  Future<Map<String, dynamic>?> _getProductById(String productId) async {
    // Ürün detaylarını ve kategorisini çek
    final products = await db.query('''
      SELECT p.*, c.name as category_name 
      FROM Products p
      LEFT JOIN Categories c ON p.category_id = c.id
      WHERE p.id = ?
    ''', [productId]);

    if (products.isEmpty) {
      return null;
    }

    // Ürün verisini hazırla
    final productData = Map<String, dynamic>.from(products.first);
    // Ürün özelliklerini çek
    final features = await db.query('''
        SELECT feature_name, feature_value
        FROM ProductFeatures
        WHERE product_id = ?
    ''', [productId]);
    // Özellikleri ürün verisine ekle
    productData['features'] = features;

    return productData;
  }
} 