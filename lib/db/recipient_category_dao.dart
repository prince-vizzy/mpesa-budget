// lib/db/recipient_category_dao.dart
import 'package:sqflite/sqflite.dart';

class RecipientCategoryDao {
  final Database _database;
  final String tableName = 'recipient_category_map';

  RecipientCategoryDao(this._database);

  Future<void> createTable() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        recipient TEXT PRIMARY KEY,
        categoryId INTEGER,
        categoryName TEXT
      )
    ''');
  }

  Future<Map<String, dynamic>?> getMapping(String recipient) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      tableName,
      where: 'recipient = ?',
      whereArgs: [recipient],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> saveMapping(
    String recipient,
    int categoryId,
    String categoryName,
  ) async {
    await _database.insert(
      tableName,
      {
        'recipient': recipient,
        'categoryId': categoryId,
        'categoryName': categoryName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}