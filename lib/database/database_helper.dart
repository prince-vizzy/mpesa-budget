import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart';

import '../models/budget_event.dart';
import '../models/category.dart';
import '../models/spend_bucket.dart';
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

/// What happened to a transaction the M-Pesa listeners handed over.
class TransactionIntake {
  /// True when a saved recipient rule filed it automatically.
  final bool wasAutoCategorized;

  /// The category it was filed under, when [wasAutoCategorized].
  final String? categoryName;

  /// True when we had already stored this transaction and did nothing.
  final bool wasDuplicate;

  /// Set when the payment landed inside an event window, naming that event.
  final String? eventName;

  const TransactionIntake._({
    this.wasAutoCategorized = false,
    this.categoryName,
    this.wasDuplicate = false,
    this.eventName,
  });

  /// Stored, and waiting for the user to pick a category.
  factory TransactionIntake.queued() => const TransactionIntake._();

  /// Stored and categorised by a saved rule.
  factory TransactionIntake.categorized(String? categoryName) =>
      TransactionIntake._(wasAutoCategorized: true, categoryName: categoryName);

  /// Stored against an event, waiting for one of its line items.
  factory TransactionIntake.queuedForEvent(String eventName) =>
      TransactionIntake._(eventName: eventName);

  /// Already known; nothing was written.
  factory TransactionIntake.duplicate() =>
      const TransactionIntake._(wasDuplicate: true);

  /// True when the payment belongs to an event rather than a normal category.
  bool get isEventSpending => eventName != null;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static sql.Database? _database;

  static const String _databaseName = 'mpesa_tracker.db';
  static const int _databaseVersion = 10;

  DatabaseHelper._privateConstructor();

  /* =========================================================
     DATABASE INIT
  ========================================================= */

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Test hook: drops any open connection and reopens against [path], so a test
  /// can run the real schema and migrations against an in-memory database.
  @visibleForTesting
  static Future<void> resetForTesting(String path) async {
    await _database?.close();
    _database = await sql.openDatabase(
      path,
      version: _databaseVersion,
      onCreate: instance._onCreate,
      onUpgrade: instance._onUpgrade,
    );
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
        status TEXT,
        name TEXT,
        user_first_name TEXT,
        raw_message TEXT,
        event_id INTEGER,
        event_category_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE uncategorized_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL,
        date INTEGER,
        name TEXT,
        user_first_name TEXT,
        raw_message TEXT,
        event_id INTEGER
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
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        starts_at INTEGER NOT NULL,
        ends_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE event_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        budget REAL DEFAULT 0
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
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE uncategorized_transactions ADD COLUMN name TEXT');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN user_first_name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE uncategorized_transactions ADD COLUMN user_first_name TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN raw_message TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE uncategorized_transactions ADD COLUMN raw_message TEXT');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            starts_at INTEGER NOT NULL,
            ends_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS event_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            budget REAL DEFAULT 0
          )
        ''');
      } catch (_) {}
      for (final statement in const [
        'ALTER TABLE transactions ADD COLUMN event_id INTEGER',
        'ALTER TABLE transactions ADD COLUMN event_category_id INTEGER',
        'ALTER TABLE uncategorized_transactions ADD COLUMN event_id INTEGER',
      ]) {
        try {
          await db.execute(statement);
        } catch (_) {}
      }
    }
    if (oldVersion < 9) {
      // recipient_category was only ever created in _onCreate, so every install
      // that arrived here by upgrading is missing it.
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recipient_category (
            recipient TEXT PRIMARY KEY,
            category_id INTEGER,
            category_name TEXT
          )
        ''');
      } catch (_) {}
    }
  }

  /* =========================================================
     EVENTS (one-off occasions with their own budget)
  ========================================================= */

  /// Creates an event and its line items together, so a half-made event can
  /// never end up owning a window with nothing to file against.
  Future<int> createEvent(BudgetEvent event) async {
    final db = await database;

    return db.transaction((txn) async {
      final eventId = await txn.insert('events', {
        'name': event.name,
        'starts_at': event.startsAt.millisecondsSinceEpoch,
        'ends_at': event.endsAt.millisecondsSinceEpoch,
        'created_at': event.createdAt.millisecondsSinceEpoch,
      });

      for (final category in event.categories) {
        await txn.insert('event_categories', {
          'event_id': eventId,
          'name': category.name,
          'budget': category.budget,
        });
      }

      return eventId;
    });
  }

  Future<void> updateEvent(BudgetEvent event) async {
    if (event.id == null) return;
    final db = await database;
    await db.update(
      'events',
      {
        'name': event.name,
        'starts_at': event.startsAt.millisecondsSinceEpoch,
        'ends_at': event.endsAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  /// Removes an event and its line items.
  ///
  /// Payments captured during it are kept, because they are real spending, but
  /// they lose the event link and return to the normal uncategorized queue to
  /// be filed against an ordinary category.
  Future<void> deleteEvent(int eventId) async {
    final db = await database;

    await db.transaction((txn) async {
      final filed = await txn.query(
        'transactions',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );

      for (final row in filed) {
        await txn.insert('uncategorized_transactions', {
          'description': row['description'],
          'amount': row['amount'],
          'date': row['date'],
          'name': row['name'],
          'user_first_name': row['user_first_name'],
          'raw_message': row['raw_message'],
        });
      }
      await txn.delete('transactions', where: 'event_id = ?', whereArgs: [eventId]);

      await txn.update(
        'uncategorized_transactions',
        {'event_id': null},
        where: 'event_id = ?',
        whereArgs: [eventId],
      );

      await txn.delete('event_categories',
          where: 'event_id = ?', whereArgs: [eventId]);
      await txn.delete('events', where: 'id = ?', whereArgs: [eventId]);
    });
  }

  Future<void> addEventCategory(int eventId, String name, double budget) async {
    final db = await database;
    await db.insert('event_categories', {
      'event_id': eventId,
      'name': name,
      'budget': budget,
    });
  }

  Future<void> updateEventCategory(EventCategory category) async {
    if (category.id == null) return;
    final db = await database;
    await db.update(
      'event_categories',
      {'name': category.name, 'budget': category.budget},
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Removes a line item. Anything filed under it goes back to the queue rather
  /// than vanishing with it.
  Future<void> deleteEventCategory(int categoryId) async {
    final db = await database;

    await db.transaction((txn) async {
      final filed = await txn.query(
        'transactions',
        where: 'event_category_id = ?',
        whereArgs: [categoryId],
      );

      for (final row in filed) {
        await txn.insert('uncategorized_transactions', {
          'description': row['description'],
          'amount': row['amount'],
          'date': row['date'],
          'name': row['name'],
          'user_first_name': row['user_first_name'],
          'raw_message': row['raw_message'],
          'event_id': row['event_id'],
        });
      }
      await txn.delete(
        'transactions',
        where: 'event_category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete('event_categories',
          where: 'id = ?', whereArgs: [categoryId]);
    });
  }

  /// The event whose window contains [moment], or null.
  ///
  /// Windows cannot overlap (the create flow refuses it), so the latest match
  /// is the only match.
  Future<BudgetEvent?> eventAt(DateTime moment) async {
    final db = await database;
    final stamp = moment.millisecondsSinceEpoch;

    final rows = await db.query(
      'events',
      where: 'starts_at <= ? AND ends_at >= ?',
      whereArgs: [stamp, stamp],
      orderBy: 'starts_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BudgetEvent.fromMap(rows.first);
  }

  /// Any event whose window overlaps [startsAt]..[endsAt], ignoring [exceptId].
  ///
  /// Two events covering the same moment would make attribution ambiguous, so
  /// the create flow uses this to refuse before saving.
  Future<BudgetEvent?> overlappingEvent(
    DateTime startsAt,
    DateTime endsAt, {
    int? exceptId,
  }) async {
    final db = await database;

    final rows = await db.query(
      'events',
      where: 'starts_at <= ? AND ends_at >= ?'
          '${exceptId == null ? '' : ' AND id != ?'}',
      whereArgs: [
        endsAt.millisecondsSinceEpoch,
        startsAt.millisecondsSinceEpoch,
        if (exceptId != null) exceptId,
      ],
      orderBy: 'starts_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BudgetEvent.fromMap(rows.first);
  }

  /// Every event, newest first, with its line items and what each has spent.
  Future<List<BudgetEvent>> getEvents() async {
    final db = await database;
    final eventRows = await db.query('events', orderBy: 'starts_at DESC');
    if (eventRows.isEmpty) return const [];

    final categoryRows = await db.query('event_categories', orderBy: 'id ASC');

    // One pass for all the spending, rather than a query per line item.
    final spendRows = await db.rawQuery('''
      SELECT event_category_id, SUM(amount) AS total
      FROM transactions
      WHERE event_category_id IS NOT NULL
      GROUP BY event_category_id
    ''');
    final spentByCategory = {
      for (final row in spendRows)
        row['event_category_id'] as int: (row['total'] as num? ?? 0).toDouble(),
    };

    return eventRows.map((eventRow) {
      final id = eventRow['id'] as int;
      final categories = categoryRows
          .where((c) => c['event_id'] == id)
          .map((c) => EventCategory.fromMap(
                c,
                spent: spentByCategory[c['id'] as int] ?? 0,
              ))
          .toList();
      return BudgetEvent.fromMap(eventRow, categories: categories);
    }).toList();
  }

  /// Payments captured during an event that still need a line item.
  Future<List<Map<String, dynamic>>> getEventQueue(int eventId) async {
    final db = await database;
    return db.query(
      'uncategorized_transactions',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'date DESC',
    );
  }

  /// Files a queued payment under one of its event line items.
  Future<void> categorizeEventTransaction({
    required int transactionId,
    required int eventCategoryId,
  }) async {
    final db = await database;

    final queued = await db.query(
      'uncategorized_transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (queued.isEmpty) return;
    final row = queued.first;

    final category = await db.query(
      'event_categories',
      where: 'id = ?',
      whereArgs: [eventCategoryId],
      limit: 1,
    );
    if (category.isEmpty) return;

    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'description': row['description'],
        'amount': row['amount'],
        'date': row['date'],
        // No category_id on purpose: the normal budgets roll up by category_id,
        // and event spending is deliberately kept out of them.
        'category_name': category.first['name'],
        'status': 'categorized',
        'name': row['name'],
        'user_first_name': row['user_first_name'],
        'raw_message': row['raw_message'],
        'event_id': row['event_id'],
        'event_category_id': eventCategoryId,
      });
      await txn.delete(
        'uncategorized_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  /// Payments filed under an event, newest first.
  Future<List<Transaction>> getEventTransactions(int eventId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'date DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /* =========================================================
     RECIPIENT RULES (auto-categorising repeat payments)
  ========================================================= */

  /// Lookup key for a payee.
  ///
  /// Recipient names come out of regexes over message text, so the same payee
  /// turns up as "Naivas Limited", "NAIVAS LIMITED." and "NAIVAS  LIMITED"
  /// depending on the wording. Matching on a normalised form means one rule
  /// covers all of them.
  static String? normalizeRecipient(String? recipient) {
    if (recipient == null) return null;
    final key = recipient
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return key.isEmpty ? null : key;
  }

  /// The saved rule for a payee, or null if this is a payee we have not been
  /// told about yet.
  Future<Map<String, dynamic>?> getRecipientCategory(String? recipient) async {
    final key = normalizeRecipient(recipient);
    if (key == null) return null;

    final db = await database;
    final rows = await db.query(
      'recipient_category',
      where: 'recipient = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Records that payments to [recipient] belong in [categoryId], so the next
  /// one files itself.
  Future<void> rememberRecipientCategory({
    required String? recipient,
    required int categoryId,
    String? categoryName,
  }) async {
    final key = normalizeRecipient(recipient);
    // Transactions the parser could not name have nothing to key a rule on.
    if (key == null) return;

    final db = await database;
    await db.insert(
      'recipient_category',
      {
        'recipient': key,
        'category_id': categoryId,
        'category_name': categoryName,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<void> forgetRecipientCategory(String? recipient) async {
    final key = normalizeRecipient(recipient);
    if (key == null) return;

    final db = await database;
    await db.delete(
      'recipient_category',
      where: 'recipient = ?',
      whereArgs: [key],
    );
  }

  /// Every saved rule, for the management list in settings.
  Future<List<Map<String, dynamic>>> getRecipientCategories() async {
    final db = await database;
    return db.query('recipient_category', orderBy: 'recipient ASC');
  }

  /* =========================================================
     USER SETTINGS
  ========================================================= */

  static const String _userFirstNameKey = 'user_first_name';

  Future<String?> getUserFirstName() async {
    return await getUserSetting(_userFirstNameKey);
  }

  Future<void> setUserFirstName(String firstName) async {
    await setUserSetting(_userFirstNameKey, firstName);
  }

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

  /// Files a transaction under a category.
  ///
  /// By default this also records a rule, so the next payment to the same payee
  /// is categorised on arrival rather than queued for the user again. Pass
  /// [rememberRecipient] as false for a one-off correction that should not
  /// change how future payments are treated.
  Future<void> categorizeTransaction({
    required int transactionId,
    required int categoryId,
    bool rememberRecipient = true,
  }) async {
    final db = await database;

    final category = (await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [categoryId],
    ))
        .first;
    final categoryName = category['name'] as String?;

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
        'category_name': categoryName,
        'status': 'categorized',
        'name': row['name'],
        'user_first_name': row['user_first_name'],
        'raw_message': row['raw_message'],
      });
      await db.delete(
        'uncategorized_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      if (rememberRecipient) {
        await rememberRecipientCategory(
          recipient: row['name'] as String?,
          categoryId: categoryId,
          categoryName: categoryName,
        );
      }
      return;
    }

    await db.update(
      'transactions',
      {
        'category_id': categoryId,
        'category_name': categoryName,
        'status': 'categorized',
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    // Re-categorising an existing transaction is also how a wrong rule gets
    // corrected, so the rule has to follow the change.
    if (rememberRecipient) {
      final rows = await db.query(
        'transactions',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await rememberRecipientCategory(
          recipient: rows.first['name'] as String?,
          categoryId: categoryId,
          categoryName: categoryName,
        );
      }
    }
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
        AND event_id IS NULL
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

  /// Total spend per period, oldest bucket first.
  ///
  /// Buckets are calendar-aligned rather than rolling windows back from now: a
  /// bar labelled "Aug" has to mean August, not the 30 days ending today.
  /// Periods with no spending come back as zero rather than missing, so the
  /// chart keeps an even time axis.
  ///
  /// This is money out, so it includes event spending. Events are held apart
  /// from the category *budgets*, not from what was actually spent.
  Future<List<SpendBucket>> getTotalSpendSeries(
    SpendGranularity granularity, {
    int buckets = 0,
  }) async {
    final count = buckets > 0 ? buckets : granularity.defaultBuckets;
    final now = DateTime.now();

    final starts = <DateTime>[
      for (int i = count - 1; i >= 0; i--)
        granularity.bucketStart(now, stepsBack: i),
    ];
    final index = {for (int i = 0; i < starts.length; i++) starts[i]: i};

    final totals = List<double>.filled(count, 0);
    for (final tx in await getAllCategorizedTransactions()) {
      final slot = index[granularity.bucketStart(tx.date)];
      if (slot != null) totals[slot] += tx.amount;
    }

    return [
      for (int i = 0; i < count; i++)
        SpendBucket(
          start: starts[i],
          label: granularity.label(starts[i]),
          total: totals[i],
        ),
    ];
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
      -- Event spending is budgeted inside its event and is deliberately left
      -- out here. Without this it would surface as an ordinary category, since
      -- an event line item writes its name into category_name.
      WHERE status = ? AND date >= ? AND event_id IS NULL
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

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await db.delete('uncategorized_transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Empties the pending-categorization queue.
  ///
  /// Only what is still waiting is removed — anything already filed under a
  /// category keeps its place and its spending. Returns how many went.
  Future<int> clearUncategorizedTransactions() async {
    final db = await database;
    return db.delete('uncategorized_transactions');
  }

  /// Payments waiting for an ordinary category.
  ///
  /// Anything captured inside an event window is excluded: it belongs to that
  /// event and is filed from the Events tab against one of its line items.
  /// Offering it here would let it land in a normal category and quietly break
  /// the separation between event and everyday spending.
  Future<List<Map<String, dynamic>>> getUncategorizedTransactions() async {
    final db = await database;
    return await db.query(
      'uncategorized_transactions',
      where: 'event_id IS NULL',
    );
  }

  /// Stores a freshly parsed transaction, applying a saved recipient rule when
  /// there is one.
  ///
  /// This is the intake point for everything the M-Pesa listeners capture.
  Future<TransactionIntake> insertParsedTransaction(Transaction transaction) async {
    final db = await database;

    final since = transaction.date
        .subtract(const Duration(minutes: 2))
        .millisecondsSinceEpoch;

    // Avoid duplicate inserts from repeated notification callbacks. The earlier
    // copy may be in either table, depending on whether a rule matched then.
    for (final table in const ['uncategorized_transactions', 'transactions']) {
      final dupes = await db.query(
        table,
        where: 'description = ? AND amount = ? AND date >= ?',
        whereArgs: [transaction.description, transaction.amount, since],
        limit: 1,
      );
      if (dupes.isNotEmpty) return TransactionIntake.duplicate();
    }

    // Get user's first name from settings and include it in the transaction
    final userFirstName = await getUserFirstName();

    // An event owns its window outright: anything paid inside it is event
    // spending, so a normal recipient rule must not claim it first. It waits
    // for one of the event's own line items instead.
    final event = await eventAt(transaction.date);
    if (event != null) {
      await db.insert('uncategorized_transactions', {
        'description': transaction.description,
        'amount': transaction.amount,
        'date': transaction.date.millisecondsSinceEpoch,
        'name': transaction.name,
        'user_first_name': userFirstName,
        'raw_message': transaction.rawMessage,
        'event_id': event.id,
      });
      return TransactionIntake.queuedForEvent(event.name);
    }

    final rule = await getRecipientCategory(transaction.name);

    if (rule == null) {
      await db.insert('uncategorized_transactions', {
        'description': transaction.description,
        'amount': transaction.amount,
        'date': transaction.date.millisecondsSinceEpoch,
        'name': transaction.name,
        'user_first_name': userFirstName,
        'raw_message': transaction.rawMessage,
      });
      return TransactionIntake.queued();
    }

    final categoryName = rule['category_name'] as String?;
    await db.insert('transactions', {
      'description': transaction.description,
      'amount': transaction.amount,
      'date': transaction.date.millisecondsSinceEpoch,
      'category_id': rule['category_id'],
      'category_name': categoryName,
      'status': 'categorized',
      'name': transaction.name,
      'user_first_name': userFirstName,
      'raw_message': transaction.rawMessage,
    });
    return TransactionIntake.categorized(categoryName);
  }

}
