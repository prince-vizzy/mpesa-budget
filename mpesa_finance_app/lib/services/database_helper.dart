import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/mpesa_transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String _userFirstNameKey = 'user_first_name';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mpesa_transactions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        phoneNumber TEXT NOT NULL,
        name TEXT,
        transactionId TEXT,
        timestamp TEXT NOT NULL,
        message TEXT,
        category TEXT,
        user_first_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN user_first_name TEXT');
      } catch (_) {}
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

  // User First Name Settings
  Future<String?> getUserFirstName() async {
    final db = await database;
    final result = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [_userFirstNameKey],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setUserFirstName(String firstName) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': _userFirstNameKey, 'value': firstName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertTransaction(MpesaTransaction transaction) async {
    final db = await database;
    // Get user's first name from settings and include it in the transaction
    final userFirstName = await getUserFirstName();
    final map = transaction.toMap();
    if (userFirstName != null) {
      map['user_first_name'] = userFirstName;
    }
    return await db.insert('transactions', map);
  }

  Future<int> updateTransactionCategory(int id, String category) async {
    final db = await database;
    return await db.update(
      'transactions',
      {'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MpesaTransaction>> getUncategorizedTransactions() async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'category IS NULL',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MpesaTransaction.fromMap(map)).toList();
  }

  Future<List<MpesaTransaction>> getAllTransactions() async {
    final db = await database;
    final result = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MpesaTransaction.fromMap(map)).toList();
  }

  Future<MpesaTransaction?> getTransactionById(String transactionId) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    if (result.isEmpty) return null;
    return MpesaTransaction.fromMap(result.first);
  }

  Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}