import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:ecommerce_backend/controllers/product_controller.dart';
import 'package:ecommerce_backend/controllers/category_controller.dart';
import 'package:ecommerce_backend/controllers/admin_controller.dart';
import 'package:ecommerce_backend/controllers/auth_controller.dart';
import 'package:ecommerce_backend/controllers/cart_controller.dart';
import 'package:ecommerce_backend/middleware/auth_middleware.dart';
import 'package:ecommerce_backend/services/database_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:ecommerce_backend/database/database.dart';
import 'dart:convert'; // JSON dönüşümleri için
import 'package:crypto/crypto.dart'; // Şifreleme işlemleri için
import 'package:ecommerce_backend/controllers/order_controller.dart';
import 'package:ecommerce_backend/controllers/favorite_controller.dart';

void main() async {
  // Veritabanı bağlantısının kurulması
  final dbPath = 'database.db';
  final absoluteDbPath = File(dbPath).absolute.path;
  print('Attempting to open database at absolute path: $absoluteDbPath');

  final sqliteDb = sqlite.sqlite3.open(dbPath);
  final db = AppDatabase(sqliteDb);

  // Controller'ların oluşturulması
  final productController = ProductController(db);
  final categoryController = CategoryController(db);
  final adminController = AdminController(db);
  final authController = AuthController(sqliteDb);
  final cartController = CartController(sqliteDb);
  final orderController = OrderController(sqliteDb);
  final favoriteController = FavoriteController(sqliteDb);

  // Ana router'ın oluşturulması
  final app = Router();

  // Test endpoint'i
  app.get('/test', (Request request) {
    print('GET /test hit!');
    return Response.ok('Test successful from server.dart!');
  });

  // Kimlik doğrulama gerektirmeyen public route'lar
  app.mount('/api/auth', authController.router);

  // Kimlik doğrulama gerektiren route'ların tanımlanması
  final authenticatedRouter = Router()
    ..mount('/products', productController.router)
    ..get('/categories', categoryController.listCategoriesHandler)
    ..get('/categories/<id|[0-9]+>', categoryController.getCategoryDetailsHandler)
    ..get('/categories/<id|[0-9]+>/products', categoryController.getProductsByCategoryIdHandler)
    ..mount('/admin', adminController.router)
    // Sepet işlemleri için endpoint'ler
    ..post('/cart/add', cartController.addToCart)
    ..get('/cart', cartController.getCartItems)
    ..put('/cart/item/<itemId>', cartController.updateCartItem)
    ..delete('/cart/item/<itemId>', cartController.removeCartItem)
    // Sipariş işlemleri için endpoint'ler
    ..post('/orders', orderController.createOrderHandler)
    ..mount('/favorites', favoriteController.router);

  // Kimlik doğrulama gerektiren route'lar için middleware pipeline'ı
  final authenticatedRoutesPipeline = Pipeline()
      .addMiddleware((handler) {
        return (request) async {
          print('[Server] Request to authenticated route pipeline: ${request.url.path}');
          return handler(request);
        };
      })
      .addMiddleware(AuthMiddleware.requireAuth)
      .addHandler(authenticatedRouter);

  // Kimlik doğrulama gerektiren route'ların ana router'a eklenmesi
  app.mount('/api', authenticatedRoutesPipeline);
  
  // Tanımlanmamış route'lar için fallback handler
  app.all('/<ignored|.*>', (Request request) {
    if (request.url.path.startsWith('api/')){
        return Response.notFound(jsonEncode({'error': 'API endpoint not found'}), headers: {'content-type': 'application/json'});
    }
    return Response.notFound('Not found');
  });

  // CORS middleware'inin global olarak uygulanması
  final finalHandler = Pipeline()
      .addMiddleware(_corsMiddleware())
      .addHandler(app);

  // Cascade handler'ın oluşturulması
  final Cascade cascadeHandler = Cascade()
      .add(finalHandler)
      .add((Request request) { 
          return Response.notFound('Fallback: Resource not found', headers: _corsHeaders);
      });

  // Sunucunun başlatılması
  final server = await shelf_io.serve(
    cascadeHandler.handler,
    InternetAddress.anyIPv4,
    8080,
  );

  // Sunucu başlatıldığında kayıtlı route'ların yazdırılması
  print('Server listening on port ${server.port}');
  print('Registered routes:');
  print('GET /test');
  print('POST /api/auth/login');
  print('POST /api/auth/register');
  print('GET /api/products');
  print('GET /api/products/<productId>');
  print('POST /api/products');
  print('PUT /api/products/<productId>');
  print('DELETE /api/products/<productId>');
  print('GET /api/categories');
  print('GET /api/categories/<categoryId>/products');
  print('POST /api/admin/products');
  print('PUT /api/admin/products/<productId>');
  print('DELETE /api/admin/products/<productId>');
  print('POST /api/cart/add');
  print('GET /api/cart');
  print('PUT /api/cart/item/<itemId>');
  print('DELETE /api/cart/item/<itemId>');
  print('POST /api/orders');
  print('POST /api/favorites');

  // Sunucunun düzgün bir şekilde kapatılması için sinyal dinleyicisi
  ProcessSignal.sigint.watch().listen((_) async {
    print('Stopping server...');
    await server.close(force: true);
    sqliteDb.dispose();
    print('Server stopped.');
    exit(0);
  });
}

// CORS (Cross-Origin Resource Sharing) middleware'i
Middleware _corsMiddleware() {
  return createMiddleware(
    requestHandler: (Request request) {
      // OPTIONS istekleri için CORS header'larını döndür
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (Response response) {
      // Tüm yanıtlara CORS header'larını ekle
      return response.change(headers: _corsHeaders);
    },
  );
}

// CORS header'larının tanımlanması
const _corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Tüm domainlerden erişime izin ver
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS', // İzin verilen HTTP metodları
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization, admin_user_id', // İzin verilen header'lar
}; 