import 'package:shelf_router/shelf_router.dart';
import '../controllers/auth_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/category_controller.dart';
import '../controllers/cart_controller.dart';
import '../controllers/order_controller.dart';
import '../controllers/favorite_controller.dart';
import 'package:sqlite3/sqlite3.dart';
import '../database/database.dart';

// API rotalarını tanımlayan fonksiyon
// app: Shelf Router nesnesi
// sqliteDb: sqlite3 Database nesnesi (direkt SQL sorguları için)
// db: AppDatabase nesnesi (daha soyutlama yapılmış database sarmalayıcı)
void apiRoutes(Router app, Database sqliteDb, AppDatabase db) {
  // Controller sınıflarından örnekler oluşturuluyor
  // Bazıları sqliteDb kullanıyor, bazıları AppDatabase kullanıyor
  final authController = AuthController(sqliteDb);
  final productController = ProductController(db);
  final categoryController = CategoryController(db);
  final cartController = CartController(sqliteDb);
  final orderController = OrderController(sqliteDb);
  final favoriteController = FavoriteController(sqliteDb);

  // --- Authentication (kullanıcı kaydı ve giriş) rotaları ---
  // POST isteğiyle /register endpoint'i AuthController'daki router ile işlenir
  app.post('/register', authController.router.call);
  // POST isteğiyle /login endpoint'i AuthController'daki router ile işlenir
  app.post('/login', authController.router.call);

  // --- Genel, halka açık rotalar ---
  // GET isteğiyle tüm ürünleri listeleme
  app.get('/products', productController.router.call);
  // Belirli kategoriye ait ürünleri listeleme, parametre <categoryId> URL'den alınır
  app.get('/products/category/<categoryId>', productController.router.call);
  // Tüm kategorileri listeleme
  app.get('/categories', categoryController.router.call);
  // Belirli ürünün detaylarını getirme, parametre <productId> URL'den alınır
  app.get('/products/<productId>', productController.router.call);

  // --- Sepet işlemleri rotaları ---
  // Sepete ürün eklemek için POST isteği
  app.post('/cart/add', cartController.addToCart);
  // Sepetteki ürünleri listelemek için GET isteği
  app.get('/cart', cartController.getCartItems);
  // Sepetteki bir ürünü güncellemek için PUT isteği, <itemId> ile ürün seçilir
  app.put('/cart/item/<itemId>', cartController.updateCartItem);
  // Sepetten bir ürünü silmek için DELETE isteği, <itemId> ile ürün seçilir
  app.delete('/cart/item/<itemId>', cartController.removeCartItem);

  // --- Sipariş işlemleri rotası ---
  // Yeni sipariş oluşturmak için POST isteği
  app.post('/orders', orderController.createOrderHandler);

  // --- Favoriler için rotalar ---
  // /favorites altındaki tüm route'lar FavoriteController içindeki router ile yönetilir
  app.mount('/favorites', favoriteController.router);
}
