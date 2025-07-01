// Gerekli paketlerin ve dosyaların içe aktarımı
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import './admin_dashboard_screen.dart';

// Ürün ekleme/düzenleme ekranı için StatefulWidget
class AdminProductFormScreen extends StatefulWidget {
  const AdminProductFormScreen({super.key, this.product});

  static const String routeName = '/admin/product-form';
  final Map<String, dynamic>? product; // Mevcut ürün verisi (düzenleme için); null ise yeni ürün

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>(); // Form doğrulama için anahtar
  bool get _isEditing => widget.product != null; // Düzenleme mi yapılıyor kontrolü

  // Form alanları için kontrolcü tanımlamaları
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockQuantityController;
  late TextEditingController _imageUrlController;
  late TextEditingController _brandController;

  int? _selectedCategoryId; // Seçilen kategori ID’si
  List<dynamic> _categories = []; // Kategori listesi
  bool _isLoadingCategories = true; // Kategori yükleniyor mu?
  bool _isSaving = false; // Kaydetme işlemi devam ediyor mu?
  String? _errorMessage; // Hata mesajı (varsa)

  @override
  void initState() {
    super.initState();
    // Ürün varsa ilgili alanları doldur
    _nameController = TextEditingController(text: widget.product?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.product?['description'] ?? '');
    _priceController = TextEditingController(text: widget.product?['price']?.toString() ?? '');
    _stockQuantityController = TextEditingController(text: widget.product?['stock_quantity']?.toString() ?? '');
    _imageUrlController = TextEditingController(text: widget.product?['image_url'] ?? '');
    _brandController = TextEditingController(text: widget.product?['brand'] ?? '');
    _selectedCategoryId = widget.product?['category_id'] as int?;
    _fetchCategories(); // Kategorileri yükle
  }

  // Kategori listesini API’den al
  Future<void> _fetchCategories() async {
    try {
      final categoriesData = await ApiService.getCategories();
      setState(() {
        _categories = categoriesData;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Kategoriler yüklenemedi: ${e.toString()}';
        _isLoadingCategories = false;
      });
    }
  }

  // Ürünü API’ye göndererek kaydet veya güncelle
  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      // Formdan alınan verileri haritaya aktar
      final productData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'category_id': _selectedCategoryId,
        'stock_quantity': int.tryParse(_stockQuantityController.text) ?? 0,
        'image_url': _imageUrlController.text,
        'brand': _brandController.text,
      };

      try {
        http.Response response;
        if (_isEditing) {
          // Güncelleme API çağrısı
          response = await ApiService.updateProduct(widget.product!['id'] as int, productData);
        } else {
          // Yeni ürün ekleme API çağrısı
          response = await ApiService.addProduct(productData);
        }

        if (mounted) {
          if (response.statusCode == 200 || response.statusCode == 201) {
            // Başarılıysa kullanıcıya mesaj göster ve yönlendir
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isEditing ? 'Ürün başarıyla güncellendi' : 'Ürün başarıyla eklendi'), backgroundColor: Colors.green),
            );
            Navigator.pushReplacementNamed(context, AdminDashboardScreen.routeName);
          } else {
            // Hata mesajı yakala ve göster
            final errorBody = jsonDecode(response.body);
            setState(() {
              _errorMessage = errorBody['error'] ?? (_isEditing ? 'Ürün güncellenemedi' : 'Ürün eklenemedi');
            });
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Bir hata oluştu: ${e.toString()}';
        });
      }

      setState(() {
        _isSaving = false;
      });
    }
  }

  // Sayfa kapatılırken controller'ları temizle
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQuantityController.dispose();
    _imageUrlController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  // Sayfanın UI kısmı
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Ürünü Düzenle' : 'Yeni Ürün Ekle')),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator()) // Kategoriler yükleniyorsa loading göster
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Hata mesajı göster
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // Ürün adı alanı
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Ürün Adı', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Ürün adı gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    // Açıklama alanı
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    // Fiyat alanı
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Fiyat (₺)', border: OutlineInputBorder(), prefixText: '₺'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Fiyat gerekli';
                        if (double.tryParse(value) == null) return 'Geçerli bir fiyat giriniz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Kategori seçimi
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      items: _categories.map<DropdownMenuItem<int>>((category) {
                        return DropdownMenuItem<int>(
                          value: category['id'] as int,
                          child: Text(category['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Kategori seçimi gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    // Stok miktarı
                    TextFormField(
                      controller: _stockQuantityController,
                      decoration: const InputDecoration(labelText: 'Stok Miktarı', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Stok miktarı gerekli';
                        if (int.tryParse(value) == null) return 'Geçerli bir stok miktarı giriniz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Görsel URL
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(labelText: 'Resim URL\'si', border: OutlineInputBorder()),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    // Marka alanı
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(labelText: 'Marka', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 25),
                    // Kaydetme butonu veya loading
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _saveProduct,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                            child: Text(_isEditing ? 'Güncelle' : 'Ekle', style: const TextStyle(fontSize: 18)),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
