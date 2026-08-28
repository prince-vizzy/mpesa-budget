import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/category.dart';
import '../models/transaction.dart';

class DashboardSyncService {
  static const List<String> _syncUrls = [
    'http://127.0.0.1:5000/api/sync',
    'http://localhost:5000/api/sync',
    'http://10.0.2.2:5000/api/sync',
  ];

  static Future<void> sync({
    required List<Category> categories,
    required List<Transaction> transactions,
  }) async {
    final payload = jsonEncode({
      'categories': categories.map(_categoryPayload).toList(),
      'transactions': transactions.map(_transactionPayload).toList(),
    });

    for (final url in _syncUrls) {
      final ok = await _post(url, payload);
      if (ok) return;
    }
  }

  static Map<String, dynamic> _categoryPayload(Category category) {
    return {
      'app_id': category.id,
      'name': category.name,
      'budget_type': category.budgetType,
      'daily_budget': category.dailyBudget,
      'weekly_budget': category.weeklyBudget,
      'monthly_budget': category.monthlyBudget,
      'spent_today': category.spentToday,
      'spent_this_week': category.spentThisWeek,
      'spent_this_month': category.spentThisMonth,
      'spent_this_year': category.spentThisYear,
    };
  }

  static Map<String, dynamic> _transactionPayload(Transaction transaction) {
    return {
      'app_id': transaction.id,
      'description': transaction.description,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'category': transaction.categoryName ?? 'Other',
      'status': transaction.status,
      'mpesa_ref': transaction.id == null ? null : 'app-${transaction.id}',
    };
  }

  static Future<bool> _post(String url, String payload) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.postUrl(Uri.parse(url)).timeout(
        const Duration(seconds: 1),
      );
      request.headers.contentType = ContentType.json;
      request.write(payload);
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
