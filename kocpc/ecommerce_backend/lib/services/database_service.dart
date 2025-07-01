import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

class DatabaseService {
  // Veritabanı nesnesini tutacak statik değişken
  static Database? _database;
  
  // Singleton için kendi kendine referans veren statik örnek
  static final DatabaseService _instance = DatabaseService._internal();

  // Factory constructor ile her çağrıda aynı _instance döner
  factory DatabaseService() {
    return _instance;
  }

  // Private named constructor (singleton örneği oluşturmak için)
  DatabaseService._internal();

  // Veritabanı nesnesini asenkron şekilde döner
  Future<Database> get database async {
    // Eğer zaten açılmışsa direkt döndür
    if (_database != null) return _database!;
    // Değilse veritabanını başlat (aç ve gerekiyorsa oluştur)
    _database = await _initDatabase();
    return _database!;
  }

  // Veritabanını başlatan, dosyayı açan ve gerekirse şemayı oluşturan özel metod
  Future<Database> _initDatabase() async {
    // Veritabanı dosya yolu (ör: çalışma dizininde 'database.db')
    final dbPath = path.join(Directory.current.path, 'database.db');
    final dbFile = File(dbPath);

    // Veritabanını sqlite3 paketiyle aç
    final db = sqlite3.open(dbPath);

    // Eğer dosya yoksa, veritabanı şemasını oluştur
    if (!dbFile.existsSync()) {
      print('Veritabanı dosyası bulunamadı, şema oluşturuluyor...');

      // Şema SQL dosyasını oku (yukarıdaki dizinde database_schema.sql)
      final schemaFile = File(path.join(Directory.current.path, '..', 'database_schema.sql'));
      final schema = await schemaFile.readAsString();

      // SQL komutlarını tek tek ayır (her noktalı virgül ';' ile)
      final statements = schema.split(';')
          .where((s) => s.trim().isNotEmpty) // boş olanları at
          .map((s) => '$s;'); // sonuna noktalı virgül ekle (SQL komutu formatı)

      // Her SQL komutunu çalıştır (tablo, index vs oluşturur)
      for (final statement in statements) {
        db.execute(statement);
      }
      print('Veritabanı şeması başarıyla oluşturuldu!');
    } else {
       print('Veritabanı dosyası bulundu.');
    }

    // Açılan ve hazır veritabanı nesnesini döndür
    return db;
  }

  // Veritabanı bağlantısını kapatır ve temizler
  Future<void> close() async {
    if (_database != null) {
      _database!.dispose();
      _database = null;
    }
  }
}
