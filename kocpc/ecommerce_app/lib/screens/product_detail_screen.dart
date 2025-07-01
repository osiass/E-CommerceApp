// Gerekli Flutter ve proje içi dosyaların import edilmesi
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // API işlemleri için servis
import './login_screen.dart'; // Giriş ekranı

// StatefulWidget: Ürün detaylarını dinamik olarak göstermek için kullanılıyor
class ProductDetailScreen extends StatefulWidget {
  static const String routeName = '/product-detail'; // Navigator ile kullanılacak route ismi

  final int productId; // Detayları gösterilecek ürünün ID'si

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _productData; // Ürün bilgilerini tutar
  bool _isLoading = true; // Yüklenme durumu
  String? _errorMessage; // Hata mesajı varsa saklanır

  @override
  void initState() {
    super.initState();
    _fetchProductDetails(); // Sayfa açıldığında ürün detaylarını getir
  }

  // Ürün detaylarını API'den çek
  Future<void> _fetchProductDetails() async {
    // Giriş kontrolü: kullanıcı giriş yapmadıysa giriş ekranına yönlendir
    if (!ApiService.isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün detaylarını görmek için lütfen giriş yapın.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // API'den ürün detayları al
      final data = await ApiService.getProductDetails(widget.productId);
      setState(() {
        _productData = data;
        _isLoading = false;
      });
    } catch (e) {
      // Hata durumunda kullanıcıya gösterilecek mesajı ayarla
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });

      // Eğer kullanıcı girişsiz işlem yapmışsa tekrar girişe yönlendir
      if (!ApiService.isLoggedIn || e.toString().contains('401') || e.toString().toLowerCase().contains('unauthorized')) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        }
      }
    }
  }

  // Sepete ekleme işlemi
  Future<void> _handleAddToCart() async {
    if (_productData == null || _productData!['id'] == null) return;
    final productId = _productData!['id'] as int;

    // Giriş kontrolü
    if (!ApiService.isLoggedIn) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sepete eklemek için lütfen giriş yapın.')),
      );
      return;
    }

    try {
      await ApiService.addToCart(productId); // API üzerinden sepete ekle
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün sepetinize eklendi!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sepete eklenemedi: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_productData != null ? _productData!['name'] ?? 'Ürün Detayı' : 'Ürün Detayı'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Yüklenme göster
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hata: $_errorMessage', style: const TextStyle(color: Colors.red)),
                      ElevatedButton(onPressed: _fetchProductDetails, child: const Text('Tekrar Dene')),
                    ],
                  ),
                )
              : _productData == null
                  ? const Center(child: Text('Ürün bilgisi bulunamadı.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Ürün resmi
                          if (_productData!['image_url'] != null && (_productData!['image_url'] as String).isNotEmpty)
                            Center(
                              child: Image.network(
                                _productData!['image_url'],
                                height: 250,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, size: 100),
                              ),
                            ),
                          const SizedBox(height: 16.0),

                          // Ürün ismi
                          Text(
                            _productData!['name'] ?? 'İsim Yok',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),

                          // Ürün fiyatı
                          Text(
                            '₺${_productData!['price'].toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),

                          // Ürün açıklaması
                          Text(
                            _productData!['description'] ?? 'Açıklama yok.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16.0),

                          // Marka bilgisi
                          if (_productData!['brand'] != null && (_productData!['brand'] as String).isNotEmpty)
                            Text('Marka: ${_productData!['brand']}', style: Theme.of(context).textTheme.titleSmall),

                          // Stok durumu
                          Text('Stok: ${_productData!['stock_quantity']}', style: Theme.of(context).textTheme.titleSmall),

                          const SizedBox(height: 16.0),
                          const Text(
                            'Teknik Özellikler:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),

                          // Teknik özellikler listesi
                          _buildFeaturesList(_productData!['features'] as List<dynamic>?),
                          const SizedBox(height: 20),

                          // Sepete Ekle butonu
                          Center(
                            child: ElevatedButton(
                              onPressed: _handleAddToCart,
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                              child: const Text('Sepete Ekle', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  // Teknik özellikler listesini oluşturan widget
  Widget _buildFeaturesList(List<dynamic>? features) {
    if (features == null || features.isEmpty) {
      return const Text('Teknik özellik bulunmamaktadır.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Liste kaydırılabilir değil
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${feature['feature_name']}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(feature['feature_value'].toString())),
            ],
          ),
        );
      },
    );
  }
}
