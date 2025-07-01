import 'package:flutter/material.dart';

// Uygulamanın farklı ekranlarını içeren dosyalar
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
// import 'screens/admin_login_screen.dart'; // Artık kullanılmıyor, kaldırıldı
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_product_form_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/favorite_screen.dart';

// API çağrıları ve kimlik doğrulama durumunu tutan servis
import 'services/api_service.dart';

// MaterialApp widget'ına erişmek ve navigasyonu kontrol etmek için global bir NavigatorKey oluşturuluyor.
// Bu, uygulama genelinde navigator işlemlerini kolaylaştırır (örneğin, context olmadan yönlendirme yapmak için).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Uygulama başlangıcı
  runApp(const MyApp());
}

// Ana uygulama widget'ı, StatelessWidget olarak tanımlanmış
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Uygulama açılırken, kullanıcı giriş yapmış mı diye kontrol edilir.
    // Eğer giriş yapılmışsa direkt HomeScreen'e, değilse LoginScreen'e yönlendirir.
    final initialRoute = ApiService.isLoggedIn ? HomeScreen.routeName : LoginScreen.routeName;

    // MaterialApp widget'ı ile temel uygulama yapısı oluşturuluyor
    return MaterialApp(
      navigatorKey: navigatorKey, // Global navigator key atanıyor, böylece app genelinde navigator'a erişim mümkün
      title: 'E-Commerce App', // Uygulama başlığı
      debugShowCheckedModeBanner: false, // Sağ üstteki debug banner gizleniyor
      theme: ThemeData(
        // Uygulamanın renk temasını belirliyoruz, deepPurple renk tohum olarak seçildi
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, // Material Design 3 kullanımı etkin
      ),
      initialRoute: initialRoute, // Başlangıç rotası yukarıda belirlenen (giriş durumu bazlı)
      // Sabit rotalar burada tanımlanır; routeName'ler ve hangi widget'ın açılacağı eşleştirilir
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(), // Giriş ekranı
        RegisterScreen.routeName: (context) => const RegisterScreen(), // Kayıt ekranı
        HomeScreen.routeName: (context) => const HomeScreen(), // Ana sayfa
        // AdminLoginScreen.routeName: (context) => const AdminLoginScreen(), // Kaldırıldı, kullanılmıyor
        AdminDashboardScreen.routeName: (context) => const AdminDashboardScreen(), // Admin paneli
        CartScreen.routeName: (context) => const CartScreen(), // Sepet ekranı
        FavoriteScreen.routeName: (context) => const FavoriteScreen(), // Favoriler ekranı
      },

      // Dinamik rotalar veya parametre ile geçirilen sayfalar için onGenerateRoute kullanılır
      onGenerateRoute: (settings) {
        // Admin ürün ekleme / düzenleme formu için rota ve parametre kontrolü
        if (settings.name == AdminProductFormScreen.routeName) {
          // Ürün bilgileri opsiyonel olarak parametre olarak geçiliyor
          final product = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => AdminProductFormScreen(product: product),
          );
        }
        // Ürün detay ekranı için rota ve parametre kontrolü
        else if (settings.name == ProductDetailScreen.routeName) {
          final productId = settings.arguments as int?;
          if (productId != null) {
            return MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: productId),
            );
          }
        }
        // Eğer başka route varsa ve yukarıdakilerden değilse null döner, böylece tanımsız route'lar hata verir
        return null;
      },
    );
  }
}
