import 'package:flutter/material.dart';
import '../services/api_service.dart';
import './login_screen.dart';
import './product_detail_screen.dart';

// Favori ürünlerin listelendiği ekran
class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});
  static const String routeName = '/favorites'; // Route adı

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<dynamic> favoriteProducts = []; // Favori ürün listesi
  bool isLoading = true; // Yükleniyor durumu
  String? error; // Hata mesajı (varsa)

  int? get _currentUserId => 1; // TODO: Gerçek kullanıcı ID'si ile değiştirilmeli (oturumdan alınmalı)

  @override
  void initState() {
    super.initState();
    _fetchFavorites(); // Sayfa yüklendiğinde favorileri getir
  }

  // Favori ürünleri API'den çeken fonksiyon
  Future<void> _fetchFavorites() async {
    if (_currentUserId == null) return; // Kullanıcı ID'si yoksa çık
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final favs = await ApiService.getFavorites(_currentUserId!); // API'den favorileri çek
      setState(() {
        favoriteProducts = favs; // Gelen favori verileri listeye atanır
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString(); // Hata mesajı kaydedilir
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')), // Başlık
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Yükleme animasyonu
          : error != null
              ? Center(child: Text('Hata: $error')) // Hata varsa göster
              : favoriteProducts.isEmpty
                  ? const Center(child: Text('Hiç favori ürününüz yok.')) // Favori yoksa mesaj
                  : ListView.builder( // Favori listesi gösteriliyor
                      itemCount: favoriteProducts.length,
                      itemBuilder: (context, index) {
                        final product = favoriteProducts[index]; // Tek ürün
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: product['image_url'] != null && product['image_url'].isNotEmpty
                                // Ürün görseli varsa göster
                                ? Image.network(
                                    product['image_url'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.image_not_supported, size: 40),
                                  )
                                // Ürün görseli yoksa ikon göster
                                : const Icon(Icons.image_not_supported, size: 40),
                            title: Text(product['name'] ?? ''), // Ürün adı
                            subtitle: Text('₺${product['price']}'), // Ürün fiyatı
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red), // Kalp simgesi
                              onPressed: () async {
                                // Favoriden çıkarma işlemi
                                await ApiService.removeFavorite(product['id'], _currentUserId!);
                                _fetchFavorites(); // Listeyi güncelle
                              },
                            ),
                            onTap: () {
                              // Ürün detay sayfasına yönlendirme
                              Navigator.pushNamed(
                                context,
                                ProductDetailScreen.routeName,
                                arguments: product['id'] as int,
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
