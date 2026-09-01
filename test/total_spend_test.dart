import 'package:flutter_test/flutter_test.dart';
// sqflite exports its own Transaction (a DB transaction handle).
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:mpesa_tracker/database/database_helper.dart';
import 'package:mpesa_tracker/models/transaction.dart';
import 'package:mpesa_tracker/models/spend_bucket.dart';

/// The totals chart buckets by calendar, not by rolling windows: a bar labelled
/// "Aug" has to mean August.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('bucketStart', () {
    test('a day bucket drops the time of day', () {
      final start = SpendGranularity.day
          .bucketStart(DateTime(2026, 9, 12, 17, 43, 9));
      expect(start, DateTime(2026, 9, 12));
    });

    test('a week bucket starts on the Monday', () {
      // 2026-09-12 is a Saturday.
      expect(
        SpendGranularity.week.bucketStart(DateTime(2026, 9, 12, 20)),
        DateTime(2026, 9, 7),
      );
      // Monday maps to itself.
      expect(
        SpendGranularity.week.bucketStart(DateTime(2026, 9, 7, 6)),
        DateTime(2026, 9, 7),
      );
      // Sunday still belongs to the week that opened on Monday.
      expect(
        SpendGranularity.week.bucketStart(DateTime(2026, 9, 13, 23, 59)),
        DateTime(2026, 9, 7),
      );
    });

    test('month and year buckets snap to the first instant', () {
      expect(
        SpendGranularity.month.bucketStart(DateTime(2026, 9, 30, 23)),
        DateTime(2026, 9, 1),
      );
      expect(
        SpendGranularity.year.bucketStart(DateTime(2026, 12, 31, 23)),
        DateTime(2026, 1, 1),
      );
    });

    test('stepping back crosses the year boundary', () {
      expect(
        SpendGranularity.month
            .bucketStart(DateTime(2026, 2, 15), stepsBack: 3),
        DateTime(2025, 11, 1),
      );
      expect(
        SpendGranularity.year.bucketStart(DateTime(2026, 6, 1), stepsBack: 2),
        DateTime(2024, 1, 1),
      );
    });

    test('stepping back a day crosses a month end', () {
      expect(
        SpendGranularity.day.bucketStart(DateTime(2026, 3, 2), stepsBack: 3),
        DateTime(2026, 2, 27),
      );
    });
  });

  group('getTotalSpendSeries', () {
    final db = DatabaseHelper.instance;

    setUp(() async {
      await databaseFactory.deleteDatabase(inMemoryDatabasePath);
      await DatabaseHelper.resetForTesting(inMemoryDatabasePath);
    });

    Future<void> spend(double amount, DateTime at) async {
      await db.insertTransactions([
        Transaction(
          description: 'TIJ${amount.toInt()} Confirmed',
          amount: amount,
          date: at,
        ),
      ]);
    }

    test('returns one bucket per period, oldest first, zeros included',
        () async {
      final series = await db.getTotalSpendSeries(SpendGranularity.day);

      expect(series, hasLength(SpendGranularity.day.defaultBuckets));
      // Empty periods are present as zero rather than missing, so the chart
      // keeps an even time axis.
      expect(series.every((b) => b.total == 0), isTrue);
      for (int i = 1; i < series.length; i++) {
        expect(series[i].start.isAfter(series[i - 1].start), isTrue);
      }
    });

    test('spending lands in the period it happened in', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      await spend(500, today.add(const Duration(hours: 9)));
      await spend(250, today.add(const Duration(hours: 20)));
      await spend(800, threeDaysAgo.add(const Duration(hours: 12)));

      final series = await db.getTotalSpendSeries(SpendGranularity.day);
      final byStart = {for (final b in series) b.start: b.total};

      // Two payments on the same day add up.
      expect(byStart[today], 750);
      expect(byStart[threeDaysAgo], 800);
    });

    test('anything older than the window is left out', () async {
      final now = DateTime.now();
      await spend(9999, DateTime(now.year - 3, now.month, 15));

      final series = await db.getTotalSpendSeries(SpendGranularity.day);
      expect(series.fold<double>(0, (sum, b) => sum + b.total), 0);
    });

    test('the bucket count can be overridden', () async {
      final series = await db.getTotalSpendSeries(
        SpendGranularity.month,
        buckets: 3,
      );
      expect(series, hasLength(3));
      // Consecutive calendar months.
      expect(series[1].start, DateTime(series[0].start.year, series[0].start.month + 1, 1));
    });
  });
}
