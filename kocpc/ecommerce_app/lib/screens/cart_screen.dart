import 'package:flutter/material.dart';
import '../services/api_service.dart';
import './login_screen.dart';

class CartScreen extends StatefulWidget {
  static const String routeName = '/cart';

  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? _cartData; // Sepetteki ürünleri ve toplam tutarı tutar
  bool _isLoading = true; // Yüklenme durumunu takip eder
  String? _errorMessage; // Hata mesajı
  String _selectedPaymentMethod = 'Credit Card'; // Seçili ödeme yöntemi (placeholder)
  bool _isProcessingOrder = false; // Sipariş oluşturulurken butonun devre dışı kalmasını sağlar

  @override
  void initState() {
    super.initState();
    _fetchCartDetails(); // Sayfa açıldığında sepet verileri alınır
  }

  // Sepet verilerini API'den alır
  Future<void> _fetchCartDetails() async {
    if (!mounted) return;

    // Giriş yapılmamışsa giriş ekranına yönlendir
    if (!ApiService.isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sepeti görüntülemek için lütfen giriş yapın.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getCart(); // Sepet verisi alınır
      setState(() {
        _cartData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });

        // Yetkisiz erişim durumunda tekrar girişe yönlendirme yapılır
        if (!ApiService.isLoggedIn || e.toString().contains('401') || e.toString().toLowerCase().contains('unauthorized')) {
          Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        }
      }
    }
  }

  // Sepetteki ürünün miktarını günceller veya 0 ise kaldırır
  Future<void> _updateItemQuantity(int cartItemId, int newQuantity) async {
    if (!mounted) return;
    if (newQuantity < 0) return;

    if (newQuantity == 0) {
      await _removeItem(cartItemId); // 0 ise ürün kaldırılır
      return;
    }

    try {
      await ApiService.updateCartItem(cartItemId, newQuantity); // Yeni miktar API'ye gönderilir
      _fetchCartDetails(); // Güncel sepet verisi yeniden alınır
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Miktar güncellenemedi: ${e.toString()}')),
        );
      }
    }
  }

  // Sepetten ürün silme işlemi
  Future<void> _removeItem(int cartItemId) async {
    if (!mounted) return;

    try {
      await ApiService.removeCartItem(cartItemId); // API çağrısı ile silinir
      _fetchCartDetails(); // Sepet yenilenir
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün silinemedi: ${e.toString()}')),
        );
      }
    }
  }

  // Sipariş oluşturma işlemi
  Future<void> _placeOrder() async {
    if (!mounted || _isProcessingOrder) return;

    if (_cartData == null || (_cartData!['items'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sepetiniz boş, sipariş oluşturulamaz.')),
      );
      return;
    }

    setState(() {
      _isProcessingOrder = true; // Sipariş işlemi başlatıldı
    });

    try {
      final orderResult = await ApiService.createOrder(); // API'den sipariş oluşturulması
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sipariş başarıyla oluşturuldu! Sipariş No: ${orderResult['order_id']}')),
        );
        setState(() {
          _cartData = {'items': [], 'total_amount': 0.0}; // Sepet görsel olarak temizlenir
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sipariş oluşturulurken hata: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false; // İşlem tamamlandı
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yedek kontrol: Giriş yapılmamışsa bilgi ver
    if (!ApiService.isLoggedIn) {
      return const Scaffold(body: Center(child: Text("Lütfen giriş yapın...")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sepetim'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Yükleniyorsa spinner göster
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hata: $_errorMessage', style: const TextStyle(color: Colors.red)),
                      ElevatedButton(onPressed: _fetchCartDetails, child: const Text('Tekrar Dene')),
                    ],
                  ),
                )
              : _cartData == null || (_cartData!['items'] as List).isEmpty
                  ? const Center(child: Text('Sepetiniz boş.')) // Sepet boşsa bilgi ver
                  : Column(
                      children: [
                        // Teslimat adresi bölümü (sadece bilgi amaçlı)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teslimat Adresi:',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8.0),
                              const Text(
                                'Kayıtlı adresiniz kullanılacaktır.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),

                        // Ödeme yöntemi gösterimi (şimdilik sabit)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ödeme Yöntemi:',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8.0),
                              Text('Seçili Yöntem: $_selectedPaymentMethod'),
                            ],
                          ),
                        ),

                        // Sepetteki ürünlerin listesi
                        Expanded(
                          child: ListView.builder(
                            itemCount: (_cartData!['items'] as List).length,
                            itemBuilder: (context, index) {
                              final item = (_cartData!['items'] as List)[index];
                              final price = item['price'] is String ? double.tryParse(item['price']) ?? 0.0 : (item['price'] as num).toDouble();
                              final quantity = item['quantity'] as int;
                              final itemTotal = price * quantity;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      // Ürün görseli
                                      if (item['image_url'] != null && (item['image_url'] as String).isNotEmpty)
                                        Image.network(
                                          item['image_url'],
                                          width: 80, height: 80, fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, size: 60),
                                        )
                                      else
                                        const SizedBox(width: 80, height: 80, child: Icon(Icons.image_not_supported, size: 60)),
                                      const SizedBox(width: 10),
                                      // Ürün bilgileri
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item['name'] ?? 'Ürün Adı Yok', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            Text('Fiyat: ₺${price.toStringAsFixed(2)}'),
                                            Text('Ara Toplam: ₺${itemTotal.toStringAsFixed(2)}'),
                                          ],
                                        ),
                                      ),
                                      // Miktar artır/azalt ve kaldır butonu
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _isProcessingOrder ? null : () => _updateItemQuantity(item['cart_item_id'], quantity - 1)),
                                              Text(quantity.toString(), style: const TextStyle(fontSize: 16)),
                                              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _isProcessingOrder ? null : () => _updateItemQuantity(item['cart_item_id'], quantity + 1)),
                                            ],
                                          ),
                                          TextButton(
                                            onPressed: _isProcessingOrder ? null : () => _removeItem(item['cart_item_id']),
                                            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Toplam tutar ve siparişi tamamlama butonu
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Toplam Tutar: ₺${(_cartData!['total_amount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _isProcessingOrder || (_cartData!['items'] as List).isEmpty ? null : _placeOrder,
                                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                                child: _isProcessingOrder 
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Siparişi Tamamla', style: TextStyle(fontSize: 18)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
