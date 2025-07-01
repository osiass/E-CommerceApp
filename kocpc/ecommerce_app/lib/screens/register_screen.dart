import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

// Kayıt ekranı widget'ı StatefulWidget olarak tanımlanıyor, çünkü kullanıcı girişi ve yüklenme durumu gibi dinamik veriler var.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  // Bu sayfanın route adı tanımlanıyor, böylece Navigator ile kolayca yönlendirme yapılabilir.
  static const String routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// Ekranın state'i burada yönetiliyor.
class _RegisterScreenState extends State<RegisterScreen> {
  // Formun durumunu kontrol etmek için bir anahtar (GlobalKey) oluşturuluyor.
  final _formKey = GlobalKey<FormState>();

  // Formdaki her bir metin alanı için TextEditingController'lar tanımlanıyor, bu sayede kullanıcı girişleri okunabilir.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // API çağrısı ve kayıt işlemi sırasında yüklenme durumunu tutan boolean değişken.
  bool _isLoading = false;

  // Kayıt sırasında oluşan hata mesajını tutmak için nullable string değişken.
  String? _error;

  // State nesnesi yok edilirken (widget kapatılırken) controller'lar dispose edilerek bellekten temizleniyor.
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Kayıt fonksiyonu: Kullanıcı kayıt bilgilerini doğrulayıp API servisine gönderiyor.
  Future<void> _register() async {
    // Öncelikle form validasyonundan geçiyor; eğer form geçersizse fonksiyon sonlanıyor.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Yükleniyor durumu aktif edilip önceki hata mesajı temizleniyor.
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // ApiService içindeki registerUser fonksiyonu çağrılıyor ve formdan alınan bilgiler parametre olarak veriliyor.
      final response = await ApiService.registerUser(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _phoneController.text,
        _addressController.text,
      );

      // Eğer widget halen ekranda ise (mounted true ise), kayıt başarılı olduysa ana sayfaya yönlendiriliyor.
      if (mounted) {
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
      }
    } catch (e) {
      // Hata yakalanırsa, hata mesajı _error değişkenine atanıyor ve ekranda gösteriliyor.
      setState(() {
        _error = e.toString();
      });
    } finally {
      // İşlem tamamlandığında (başarılı ya da başarısız) yükleniyor durumu kapatılıyor.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget ağacının ana yapısı: Scaffold içinde AppBar ve form yer alıyor.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'), // Üst bar başlığı
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Ekranın her tarafından boşluk bırakılıyor
        child: Form(
          key: _formKey, // Formun global anahtarı form doğrulaması için kullanılıyor
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // İsim alanı: TextFormField ile input alınıyor, boş bırakılırsa uyarı veriliyor
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'İsim',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'İsim gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16), // Arada boşluk

              // Email alanı: Email formatında giriş için klavye tipi ayarlanmış, '@' kontrolü yapılıyor
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email gerekli';
                  }
                  if (!value.contains('@')) {
                    return 'Geçerli bir email adresi girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Şifre alanı: Girdi gizleniyor (obscureText), en az 6 karakter şartı var
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre gerekli';
                  }
                  if (value.length < 6) {
                    return 'Şifre en az 6 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Telefon alanı: Telefon klavyesi açılıyor, boş olamaz
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon Numarası',
                  hintText: 'Örn: +9055... veya 055...',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Telefon numarası gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Adres alanı: Çok satırlı alan, boş olamaz
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Adres gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Eğer _error doluysa (kayıt sırasında hata varsa) hata mesajı kırmızı renkte gösteriliyor
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Kayıt ol butonu: Yüklenme durumuna göre aktif veya pasif, yükleniyorsa spinner gösteriliyor
              SizedBox(
                width: double.infinity, // Buton tüm yatay alanı kaplar
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register, // Yükleniyorsa tıklanmaz
                  child: _isLoading
                      ? const CircularProgressIndicator() // Yükleniyor göstergesi
                      : const Text('Kayıt Ol'), // Buton yazısı
                ),
              ),
              const SizedBox(height: 16),

              // Giriş sayfasına yönlendiren metin butonu
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Zaten hesabınız var mı? Giriş yapın'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
