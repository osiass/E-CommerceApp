import 'package:sqlite3/sqlite3.dart' as sqlite;

// SQLite veritabanı işlemlerini kolaylaştırmak için sarmalayan sınıf
class AppDatabase {
  // sqlite3 veritabanı nesnesi (gerçek bağlantı)
  final sqlite.Database _db;

  // Constructor: dışarıdan veritabanı nesnesi alınır
  AppDatabase(this._db);

  // SQL sorgusu çalıştırarak çoklu kayıtları liste halinde döndürür
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    // Verilen SQL ve parametrelerle sorgu çalıştırılır
    final result = _db.select(sql, params ?? []);
    // Sonuçtaki her satır Map<String, dynamic> formatına dönüştürülür
    return result.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  // SQL komutu çalıştırır (insert, update, delete vb. için)
  Future<void> execute(String sql, [List<dynamic>? params]) async {
    // SQL ve parametrelerle komut çalıştırılır
    _db.execute(sql, params ?? []);
  }

  // Belirtilen tabloya veri ekler, eklenen satırın ID'sini döner
  Future<int> insert(String table, Map<String, dynamic> data) async {
    // Eklenen sütun isimleri virgülle ayrılarak alınır
    final columns = data.keys.join(', ');
    // Her sütun için ? yer tutucu hazırlanır
    final placeholders = List.filled(data.length, '?').join(', ');
    // Verilerin değerleri listeye dönüştürülür
    final values = data.values.toList();

    // INSERT sorgusu oluşturulur
    final sql = 'INSERT INTO $table ($columns) VALUES ($placeholders)';
    // Sorgu ve parametreler ile veritabanına kayıt yapılır
    _db.execute(sql, values);

    // Son eklenen satırın ID'si geri döndürülür
    return _db.lastInsertRowId;
  }

  // Belirtilen tabloda güncelleme yapar
  Future<void> update(String table, Map<String, dynamic> data, String whereClause, [List<dynamic>? whereArgs]) async {
    // SET kısmında her sütun için "column = ?" formatı hazırlanır
    final setClause = data.keys.map((key) => '$key = ?').join(', ');

    // Güncellenecek değerler ve WHERE koşulundaki parametreler birleştirilir
    final values = [...data.values, ...?whereArgs];

    // UPDATE sorgusu oluşturulur
    final sql = 'UPDATE $table SET $setClause WHERE $whereClause';

    // Sorgu çalıştırılır
    _db.execute(sql, values);
  }

  // Belirtilen tabloda silme işlemi yapar
  Future<void> delete(String table, String whereClause, [List<dynamic>? whereArgs]) async {
    // DELETE sorgusu oluşturulur
    final sql = 'DELETE FROM $table WHERE $whereClause';

    // Sorgu ve parametreler ile silme işlemi gerçekleştirilir
    _db.execute(sql, whereArgs ?? []);
  }
}
