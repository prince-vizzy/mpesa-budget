import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart';

import '../models/category.dart';
import '../models/transaction.dart';

class SpendRollup {
  final double today;
  final double week;
  final double month;
  final double year;
  const SpendRollup({
    required this.today,
    required this.week,
    required this.month,
    required this.year,
  });
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static sql.Database? _database;

  static const String _databaseName = 'mpesa_tracker.db';
  static const int _databaseVersion = 5;

  DatabaseHelper._privateConstructor();

  /* =========================================================
     DATABASE INIT
  ========================================================= */

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sql.Database> _initDatabase() async {
    final path = join(await sql.getDatabasesPath(), _databaseName);
    return await sql.openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sql.Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        budget_type TEXT DEFAULT 'daily',
        daily_budget REAL,
        weekly_budget REAL,
        monthly_budget REAL DEFAULT 0,
        spent_today REAL,
        spent_this_week REAL,
        spent_this_month REAL DEFAULT 0,
        spent_this_year REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL,
        date INTEGER,
        category_id INTEGER,
        category_name TEXT,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE uncategorized_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL,
        date INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE recipient_category (
        recipient TEXT PRIMARY KEY,
        category_id INTEGER,
        category_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(
    sql.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT "categorized"',
        );
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN budget_type TEXT DEFAULT "daily"',
        );
        await db.execute(
          'ALTER TABLE categories ADD COLUMN monthly_budget REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE categories ADD COLUMN spent_this_month REAL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      } catch (_) {}
    }
  }

  /* =========================================================
     USER SETTINGS
  ========================================================= */

  Future<String?> getUserSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setUserSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  /* =========================================================
     CATEGORY
  ========================================================= */

  Future<void> insertCategory(Category category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map(Category.fromMap).toList();
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /* =========================================================
     TRANSACTIONS
  ========================================================= */

  Future<void> categorizeTransaction({
    required int transactionId,
    required int categoryId,
  }) async {
    final db = await database;

    final category = (await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    ))
        .first;

    // If this id belongs to uncategorized_transactions, move it into
    // transactions as categorized, then remove from uncategorized queue.
    final uncategorized = await db.query(
      'uncategorized_transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (uncategorized.isNotEmpty) {
      final row = uncategorized.first;
      await db.insert('transactions', {
        'description': row['description'],
        'amount': row['amount'],
        'date': row['date'],
        'category_id': categoryId,
        'category_name': category['name'],
        'status': 'categorized',
      });
      await db.delete(
        'uncategorized_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      return;
    }

    await db.update(
      'transactions',
      {
        'category_id': categoryId,
        'category_name': category['name'],
        'status': 'categorized',
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<List<Transaction>> getAllCategorizedTransactions() async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'status = ?',
      whereArgs: ['categorized'],
      orderBy: 'date DESC',
    );

    return result.map(Transaction.fromMap).toList();
  }

  Future<Map<int, SpendRollup>> getCategorySpendRollups() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .millisecondsSinceEpoch;
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final startOfYear = DateTime(now.year, 1, 1).millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT
        category_id,
        SUM(CASE WHEN date >= ? THEN amount ELSE 0 END) AS spent_today,
        SUM(CASE WHEN date >= ? THEN amount ELSE 0 END) AS spent_week,
        SUM(CASE WHEN date >= ? THEN amount ELSE 0 END) AS spent_month,
        SUM(CASE WHEN date >= ? THEN amount ELSE 0 END) AS spent_year
      FROM transactions
      WHERE status = 'categorized' AND category_id IS NOT NULL
      GROUP BY category_id
      ''',
      [startOfDay, startOfWeek, startOfMonth, startOfYear],
    );

    final result = <int, SpendRollup>{};
    for (final row in rows) {
      final id = (row['category_id'] as num).toInt();
      result[id] = SpendRollup(
        today: (row['spent_today'] as num? ?? 0).toDouble(),
        week: (row['spent_week'] as num? ?? 0).toDouble(),
        month: (row['spent_month'] as num? ?? 0).toDouble(),
        year: (row['spent_year'] as num? ?? 0).toDouble(),
      );
    }
    return result;
  }

  Future<Map<String, double>> getCategorySpendingByDays(int days) async {
    final db = await database;
    final startTime = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(category_name, 'Uncategorized') AS category_name,
        SUM(amount) AS total
      FROM transactions
      WHERE status = ? AND date >= ?
      GROUP BY COALESCE(category_name, 'Uncategorized')
      ORDER BY total DESC
      ''',
      ['categorized', startTime],
    );

    final data = <String, double>{};
    for (final row in result) {
      final name = row['category_name']?.toString() ?? 'Uncategorized';
      data[name] = (row['total'] as num? ?? 0).toDouble();
    }
    return data;
  }

  Future<void> insertTransactions(List<Transaction> transactions) async {
    if (transactions.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (final transaction in transactions) {
      final map = transaction.toMap()..remove('id');
      batch.insert(
        'transactions',
        map,
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('uncategorized_transactions');
  }

  Future<List<Map<String, dynamic>>> getUncategorizedTransactions() async {
    final db = await database;
    return await db.query('uncategorized_transactions');
  }

  Future<void> insertUncategorizedTransaction(Transaction transaction) async {
    final db = await database;

    // Avoid duplicate inserts from repeated notification callbacks.
    final dupes = await db.query(
      'uncategorized_transactions',
      where: 'description = ? AND amount = ? AND date >= ?',
      whereArgs: [
        transaction.description,
        transaction.amount,
        transaction.date.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
      ],
      limit: 1,
    );
    if (dupes.isNotEmpty) return;

    await db.insert('uncategorized_transactions', {
      'description': transaction.description,
      'amount': transaction.amount,
      'date': transaction.date.millisecondsSinceEpoch,
    });
  }
}
