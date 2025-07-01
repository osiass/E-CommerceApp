import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // API işlemleri için servis sınıfı
import 'login_screen.dart'; // Giriş ekranı - çıkış yapılınca yönlendirme
import 'admin_product_form_screen.dart'; // Yeni ürün ekleme ve düzenleme ekranı

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  static const String routeName = '/admin'; // Route tanımı

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> products = []; // Ürün listesi
  List<dynamic> categories = []; // Kategori listesi
  bool isLoading = true; // Yükleniyor mu durumu
  String? error; // Hata mesajı

  @override
  void initState() {
    super.initState();
    _loadData(); // Sayfa açıldığında veri yükle
  }

  Future<void> _loadData() async {
    // Kullanıcı giriş yapmamışsa login sayfasına yönlendir
    if (!ApiService.isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
      return;
    }

    // Veri yükleme başlatılıyor
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // API'den ürün ve kategori verilerini al
      final productsData = await ApiService.getProducts();
      final categoriesData = await ApiService.getCategories();

      if (mounted) {
        // Ekranı güncelle
        setState(() {
          products = productsData;
          categories = categoriesData;
          isLoading = false;
        });
      }
    } catch (e) {
      // Hata oluşursa hata mesajını göster
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  // Kategori silme işlemi
  Future<void> _deleteCategory(int categoryId) async {
    try {
      await ApiService.deleteCategory(categoryId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori başarıyla silindi')),
      );
      _loadData(); // Listeyi güncelle
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori silinemedi: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yükleniyor animasyonu
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Hata varsa göster
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hata: $error'),
              ElevatedButton(
                onPressed: _loadData, // Yeniden dene
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    // Ana yönetici ekranı
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Çıkış işlemi ve login ekranına yönlendirme
              ApiService.clearToken();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------- Kategoriler Bölümü -----------
            const Text(
              'Kategoriler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Kategori listesi
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Scroll çakışmasını önler
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  child: ListTile(
                    title: Text(category['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // Kategori silme onaylama penceresi
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Kategoriyi Sil'),
                            content: Text('${category['name']} kategorisini silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Dialog kapat
                                  _deleteCategory(category['id']); // Sil
                                },
                                child: const Text('Sil', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ----------- Ürünler Bölümü -----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ürünler',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Yeni ürün ekleme formuna git
                    Navigator.pushNamed(
                      context,
                      AdminProductFormScreen.routeName,
                    ).then((_) => _loadData()); // Dönünce listeyi yenile
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Ürün'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ürün listesi
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Sayfa içi scroll sorunu yaşamamak için
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: ListTile(
                    leading: product['image_url'] != null && product['image_url'].isNotEmpty
                        ? Image.network(
                            product['image_url'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.broken_image); // Görsel yüklenemezse
                            },
                          )
                        : const Icon(Icons.image_not_supported), // Görsel yoksa
                    title: Text(product['name']),
                    subtitle: Text('₺${product['price'].toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ürün düzenleme
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // Ürün düzenleme formuna yönlendirme
                            Navigator.pushNamed(
                              context,
                              AdminProductFormScreen.routeName,
                              arguments: product, // Mevcut ürün verisi gönderilir
                            ).then((_) => _loadData()); // Geri dönünce güncelle
                          },
                        ),
                        // Ürün silme
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            try {
                              await ApiService.deleteProduct(product['id']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ürün başarıyla silindi')),
                              );
                              _loadData(); // Listeyi yenile
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ürün silinemedi: ${e.toString()}')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
