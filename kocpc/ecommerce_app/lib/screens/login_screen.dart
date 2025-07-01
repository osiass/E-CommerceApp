// Gerekli paketlerin ve dosyaların içe aktarılması
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // API servisleri
import 'home_screen.dart'; // Kullanıcı ana sayfası
import 'register_screen.dart'; // Kayıt ekranı
import 'admin_dashboard_screen.dart'; // Admin paneli

// Giriş ekranı widget'ı
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login'; // Navigator ile kullanılacak route ismi

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// State sınıfı: ekranın davranışını tanımlar
class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(); // Email girişi için kontrolcü
  final passwordController = TextEditingController(); // Şifre girişi için kontrolcü
  bool isLoading = false; // Yüklenme durumu

  // Giriş başarılıysa ilgili sayfaya yönlendirme yapılır
  Future<void> _handleNavigation(bool isAdmin) async {
    if (!mounted) return; // Widget ağaca bağlı değilse çık

    await Future.microtask(() {
      if (!mounted) return;
      if (isAdmin) {
        // Admin ise admin paneline yönlendir
        Navigator.of(context).pushReplacementNamed(AdminDashboardScreen.routeName);
      } else {
        // Normal kullanıcı ise ana sayfaya yönlendir
        Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
      }
    });
  }

  // Giriş yapma fonksiyonu
  void login() async {
    if (isLoading) return; // Yüklenme sırasında tekrar tetiklenmesin

    setState(() => isLoading = true); // Yüklenme başlat

    try {
      // API'ye giriş isteği gönder
      final response = await ApiService.loginUser(
        emailController.text,
        passwordController.text,
      );

      if (!mounted) return;

      // Başarılı giriş kontrolü
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final user = responseBody['user']; // Kullanıcı bilgileri
        final token = responseBody['token']; // Token bilgisi
        final isAdmin = user['is_admin'] as bool? ?? false; // Admin mi kontrol et

        // Token varsa sakla
        if (token != null) {
          ApiService.setToken(token); // Token’ı kaydet (örneğin header’larda kullanılmak için)
          print('Token saved successfully.');
        } else {
          print('Error: Token not received in login response.');
        }

        // Rolüne göre yönlendir
        await _handleNavigation(isAdmin);
      } else {
        // Giriş başarısızsa kullanıcıya hata mesajı göster
        final responseBody = jsonDecode(response.body);
        final errorMessage = responseBody['error'] ?? 'Bilinmeyen bir hata oluştu.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Giriş başarısız: $errorMessage')),
          );
        }
      }
    } catch (e) {
      // Genel hata yakalama
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } finally {
      // Her durumda yüklenme durumunu kapat
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Arayüz tanımı
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap')), // Üst bar
      body: SafeArea(
        child: SingleChildScrollView( // Klavye açıldığında kayabilir yapı
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Kenar boşlukları
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Email alanı
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                // Şifre alanı
                TextField(
                  controller: passwordController,
                  obscureText: true, // Şifre gizli görünür
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                // Giriş yap butonu
                ElevatedButton(
                  onPressed: isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2), // Yükleme animasyonu
                      )
                    : const Text('Giriş Yap'),
                ),
                const SizedBox(height: 16),
                // Kayıt ekranına yönlendirme
                TextButton(
                  onPressed: isLoading 
                    ? null 
                    : () => Navigator.pushNamed(context, RegisterScreen.routeName),
                  child: const Text('Hesabınız yok mu? Kayıt ol'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bellek sızıntısı olmaması için kontrolcüleri serbest bırak
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
