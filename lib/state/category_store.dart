import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/dashboard_sync_service.dart';

class CategoryStore with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Category> _categories = [];
  List<Transaction> _uncategorizedTransactions = [];

  List<Category> get categories => _categories;
  List<Transaction> get uncategorizedTransactions =>
      _uncategorizedTransactions;

  CategoryStore() {
    _init();
  }

  Future<void> _init() async {
    await loadAllData();
  }

  /* =========================================================
     CORE LOADERS
  ========================================================= */

  Future<void> loadAllData() async {
    await Future.wait([
      loadCategories(),
      loadUncategorizedTransactions(),
    ]);
    await _syncDashboard();
  }

  Future<void> loadCategories() async {
    _categories = await _dbHelper.getAllCategories();

    // Remove any existing "General" categories from the DB.
    for (final c in _categories) {
      if (c.name.trim().toLowerCase() == 'general' && c.id != null) {
        await _dbHelper.deleteCategory(c.id!);
      }
    }
    _categories = await _dbHelper.getAllCategories();

    final rollups = await _dbHelper.getCategorySpendRollups();
    _categories = _categories.map((c) {
      final id = c.id;
      if (id == null) {
        return c.copyWith(spentToday: 0, spentThisWeek: 0, spentThisMonth: 0, spentThisYear: 0);
      }
      final r = rollups[id];
      return c.copyWith(
        spentToday: r?.today ?? 0,
        spentThisWeek: r?.week ?? 0,
        spentThisMonth: r?.month ?? 0,
        spentThisYear: r?.year ?? 0,
      );
    }).toList();

    notifyListeners();
  }

  Future<void> loadUncategorizedTransactions() async {
    final maps = await _dbHelper.getUncategorizedTransactions();
    _uncategorizedTransactions =
        maps.map(Transaction.fromMap).toList();
    notifyListeners();
  }

  /* =========================================================
     CATEGORY CRUD
  ========================================================= */

  Future<void> addCategory(Category category) async {
    await _dbHelper.insertCategory(category);
    await loadCategories();
    await _syncDashboard();
  }

  Future<void> updateCategory(Category category) async {
    await _dbHelper.updateCategory(category);
    await loadCategories();
    await _syncDashboard();
  }

  Future<void> deleteCategory(int id) async {
    await _dbHelper.deleteCategory(id);
    await loadCategories();
    await _syncDashboard();
  }

  Future<void> deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
    await loadCategories();
    await _syncDashboard();
  }

  /* =========================================================
     TRANSACTIONS
     (categoryName kept for Dashboard compatibility)
  ========================================================= */

  Future<void> categorizeTransaction({
    required int transactionId,
    required int categoryId,
    String? categoryName, // 👈 REQUIRED BY DASHBOARD
    // Pass false for a one-off correction that should not change how future
    // payments to this payee are treated.
    bool rememberRecipient = true,
  }) async {
    await _dbHelper.categorizeTransaction(
      transactionId: transactionId,
      categoryId: categoryId,
      rememberRecipient: rememberRecipient,
    );

    await loadAllData();
  }

  /* =========================================================
     RECIPIENT RULES (auto-categorising repeat payments)
  ========================================================= */

  /// Every saved payee rule, for the management list in settings.
  Future<List<Map<String, dynamic>>> getRecipientRules() =>
      _dbHelper.getRecipientCategories();

  /// Stops auto-categorising payments to this payee. Transactions already filed
  /// keep their category; only future ones go back to the queue.
  Future<void> forgetRecipientRule(String recipient) async {
    await _dbHelper.forgetRecipientCategory(recipient);
    notifyListeners();
  }

  Future<List<Transaction>> getAllCategorizedTransactions() async {
    return await _dbHelper.getAllCategorizedTransactions();
  }

  /* =========================================================
     DASHBOARD SUPPORT (RESTORED)
  ========================================================= */

  Future<Map<String, double>> getCategorySpendingData(int days) async {
    return await _dbHelper.getCategorySpendingByDays(days);
  }

  /* =========================================================
     HISTORY PAGE (SAFE PLACEHOLDERS)
  ========================================================= */

  Future<Map<int, double>> getDailySpendingData(int days) async =>
      _emptySeries(days);

  Future<Map<int, double>> getWeeklySpendingData(int weeks) async =>
      _emptySeries(weeks);

  Future<Map<int, double>> getMonthlySpendingData(int months) async =>
      _emptySeries(months);

  Future<Map<int, double>> getAnnualSpendingData(int years) async =>
      _emptySeries(years);

  Future<Map<String, List<double>>> getCategoryTrendSeries({
    required int bucketCount,
    required Duration bucketSize,
  }) async {
    final transactions = await _dbHelper.getAllCategorizedTransactions();
    final now = DateTime.now();
    final start = now.subtract(
      Duration(seconds: bucketSize.inSeconds * bucketCount),
    );

    final series = <String, List<double>>{};
    for (final tx in transactions) {
      if (tx.date.isBefore(start) || tx.date.isAfter(now)) continue;
      final bucketIndex =
          tx.date.difference(start).inSeconds ~/ bucketSize.inSeconds;
      if (bucketIndex < 0 || bucketIndex >= bucketCount) continue;

      final category = tx.categoryName?.trim().isNotEmpty == true
          ? tx.categoryName!.trim()
          : 'Uncategorized';
      final values = series.putIfAbsent(
        category,
        () => List<double>.filled(bucketCount, 0),
      );
      values[bucketIndex] += tx.amount;
    }

    return series;
  }

  Future<void> _syncDashboard() async {
    try {
      final transactions = await getAllCategorizedTransactions();
      await DashboardSyncService.sync(
        categories: _categories,
        transactions: transactions,
      );
    } catch (_) {
      // Dashboard sync is best-effort; local app data remains authoritative.
    }
  }

  /* =========================================================
     UTIL
  ========================================================= */

  Map<int, double> _emptySeries(int length) {
    return {for (int i = 0; i < length; i++) i: 0.0};
  }
}
