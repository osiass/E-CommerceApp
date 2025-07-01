import 'package:flutter/material.dart';
import '../services/api_service.dart';
import './product_detail_screen.dart'; // ProductDetailScreen import edildi
import './login_screen.dart'; // Import LoginScreen
import './cart_screen.dart'; // Import CartScreen (will be created)
import 'dart:async';
import './favorite_screen.dart'; // Import FavoriteScreen

// Ana ekran widget'ı - Ürün listesi, kategoriler ve arama özelliklerini içerir
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Ürün ve kategori listelerini tutan değişkenler
  List<dynamic> products = [];
  List<dynamic> categories = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = ''; // Arama sorgusunu tutacak state
  int? _selectedCategoryId; // Seçili kategori ID'sini tutacak state
  // Favori ürün ID'lerini tutacak liste
  Set<int> favoriteProductIds = {};

  @override
  void initState() {
    super.initState();
    _initializeData(); // Uygulama başladığında verileri yükle
    _fetchFavorites(); // Favori ürünleri getir
  }

  // Uygulama başlangıcında verileri yükleyen fonksiyon
  Future<void> _initializeData() async {
    if (!mounted) return;
    
    // Kullanıcı giriş yapmamışsa login ekranına yönlendir
    if (!ApiService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        }
      });
      return;
    }

    await _loadData();
  }

  // Ürün ve kategori verilerini API'den yükleyen fonksiyon
  Future<void> _loadData({bool loadAllProducts = true}) async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      error = null;
      if (loadAllProducts) {
        _selectedCategoryId = null;
      }
    });

    try {
      // Seçili kategori varsa o kategorinin ürünlerini, yoksa tüm ürünleri getir
      final productsData = _selectedCategoryId == null || loadAllProducts
          ? await ApiService.getProducts()
          : await ApiService.getProductsByCategory(_selectedCategoryId!);
      
      // Kategorileri sadece ilk yüklemede getir
      if (categories.isEmpty) {
        final categoriesData = await ApiService.getCategories();
        if (mounted) {
          setState(() {
            categories = categoriesData;
          });
        }
      }
      
      if (mounted) {
        setState(() {
          products = productsData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
        
        // Oturum hatası varsa login ekranına yönlendir
        if (!ApiService.isLoggedIn || e.toString().contains('401')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
            }
          });
        }
      }
    }
  }

  // Arama sorgusuna göre ürünleri filtreleyen getter
  List<dynamic> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return products; // Arama sorgusu boşsa tüm ürünleri döndür
    }
    return products.where((product) {
      final productName = product['name'].toString().toLowerCase();
      final searchQuery = _searchQuery.toLowerCase();
      return productName.contains(searchQuery); // Ürün adı arama sorgusunu içeriyorsa
    }).toList();
  }

  // Kategori seçildiğinde çağrılan fonksiyon
  void _onCategorySelected(int categoryId) {
    if (!mounted) return;
    
    setState(() {
      if (_selectedCategoryId == categoryId) {
        // Aynı kategoriye tekrar tıklandıysa seçimi kaldır ve tüm ürünleri yükle
        _selectedCategoryId = null;
        _loadData(loadAllProducts: true);
      } else {
        _selectedCategoryId = categoryId;
        _loadData(loadAllProducts: false); // Sadece seçili kategorinin ürünlerini yükle
      }
      _searchQuery = ''; // Kategori değiştiğinde arama sorgusunu sıfırla
    });
  }

  // Sepete ürün ekleme fonksiyonu
  Future<void> _handleAddToCart(int productId) async {
    if (!ApiService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamed(LoginScreen.routeName);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sepete eklemek için lütfen giriş yapın.')),
          );
        }
      });
      return;
    }

    try {
      await ApiService.addToCart(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün sepetinize eklendi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sepete eklenemedi: ${e.toString()}')),
        );
      }
    }
  }

  // Çıkış yapma fonksiyonu
  void _logout() {
    ApiService.clearToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    });
  }

  // Kullanıcı ID'sini almak için (örnek: login response'dan veya localden)
  int? get _currentUserId {
    // Burada kullanıcı ID'sini uygun şekilde al
    // Örneğin: ApiService.currentUserId veya SharedPreferences vs.
    // Şimdilik test için sabit bir değer döndürüyorum (ör: 1)
    return 1;
  }

  // Favori ürünleri getiren fonksiyon
  Future<void> _fetchFavorites() async {
    if (_currentUserId == null) return;
    try {
      final favs = await ApiService.getFavorites(_currentUserId!);
      setState(() {
        favoriteProductIds = favs.map<int>((e) => e['id'] as int).toSet();
      });
    } catch (e) {
      // Hata durumunda favoriler boş kalır
    }
  }

  // Favori ekleme/çıkarma fonksiyonu
  Future<void> _toggleFavorite(int productId) async {
    if (_currentUserId == null) return;
    final isFav = favoriteProductIds.contains(productId);
    try {
      if (isFav) {
        await ApiService.removeFavorite(productId, _currentUserId!);
        setState(() {
          favoriteProductIds.remove(productId);
        });
      } else {
        await ApiService.addFavorite(productId, _currentUserId!);
        setState(() {
          favoriteProductIds.add(productId);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favori işlemi başarısız: $e')),
      );
    }
  }

  // Kategori ikonlarını belirleyen yardımcı fonksiyon
  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'elektronik':
        return Icons.devices;
      case 'telefonlar':
        return Icons.phone_android;
      case 'bilgisayarlar':
        return Icons.computer;
      case 'laptop':
        return Icons.laptop;
      case 'masaüstü bilgisayar':
        return Icons.desktop_windows;
      case 'bileşenler':
        return Icons.settings_input_component;
      case 'ekran kartı':
        return Icons.sd_card;
      case 'işlemci':
        return Icons.memory;
      case 'aksesuarlar':
        return Icons.headset;
      case 'mouse':
        return Icons.mouse;
      case 'klavye':
        return Icons.keyboard;
      case 'monitör':
        return Icons.monitor;
      default:
        return Icons.category;
    }
  }

  // Kategori kartı widget'ını oluşturan fonksiyon
  Widget _buildCategoryCard(int categoryId, String title, IconData icon, bool isSelected, Function(int) onTap) {
    return GestureDetector(
      onTap: () => onTap(categoryId),
      child: Container(
        width: 100,
        height: 90,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal[300] : Colors.blue[100], // Seçiliyse farklı renk
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Colors.teal, width: 2) : null, // Seçiliyse kenarlık
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Ürün kartı widget'ını oluşturan fonksiyon
  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['id'] as int;
    final isFavorite = favoriteProductIds.contains(productId);
    return SizedBox(
      height: 340,
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün resmi ve favori butonu
            Stack(
              children: [
                SizedBox(
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: product['image_url'] != null && product['image_url'].isNotEmpty
                        ? Image.network(
                            product['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image, size: 50),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                  ),
                ),
                // Favori butonu
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(productId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            // Ürün detayları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₺${product['price'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Stok: ${product['stock_quantity']}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 2),
                  // Detay ve Sepete Ekle butonları
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (!ApiService.isLoggedIn) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Navigator.pushNamed(context, LoginScreen.routeName);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ürün detaylarını görmek için lütfen giriş yapın.')),
                                  );
                                }
                              });
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Navigator.pushNamed(
                                    context,
                                    ProductDetailScreen.routeName,
                                    arguments: product['id'] as int,
                                  ).then((_) {
                                    // Detay ekranından dönünce ürün listesini yenile
                                    _loadData();
                                  });
                                }
                              });
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Detay', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAddToCart(product['id'] as int),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Sepete Ekle', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiService.isLoggedIn && !isLoading) {
      return const Scaffold(body: Center(child: Text("Giriş yapılıyor...")));
    }

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hata: $error'),
              ElevatedButton(
                onPressed: () => _loadData(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('KOÇPC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Favorilerim',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteScreen(),
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              if (!ApiService.isLoggedIn) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pushNamed(LoginScreen.routeName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sepeti görüntülemek için lütfen giriş yapın.')),
                    );
                  }
                });
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pushNamed(CartScreen.routeName);
                  }
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Arama Çubuğu
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ürün ara...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _searchQuery = value;
                    });
                  }
                },
              ),
            ),

            // Kategoriler
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: categories.map((category) {
                    return _buildCategoryCard(
                      category['id'] as int, // ID'yi int olarak ver
                      category['name'],
                      _getCategoryIcon(category['name']),
                      _selectedCategoryId == category['id'], // Seçili olup olmadığını kontrol et
                      _onCategorySelected, // Tıklama fonksiyonunu ver
                    );
                  }).toList(),
                ),
              ),
            ),

            // Reklam Alanı
            Container(
              margin: const EdgeInsets.all(8),
              height: 110,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kampanya detayları yakında!')),
                  );
                },
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Image.asset(
                      'assets/kampanya.jpg',
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'SSD, RAM, Monitör,\nOyuncu Ekipmanlarında',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '%20\'ye varan indirim!',
                            style: TextStyle(fontSize: 16, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

            // Ürün Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _filteredProducts.length, // Filtrelenmiş ürün sayısını kullan
              itemBuilder: (context, index) {
                final product = _filteredProducts[index]; // Filtrelenmiş ürünü al
                return _buildProductCard(product);
              },
            ),
          ],
        ),
      ),
    );
  }
}
