// lib/models/spend_bucket.dart

/// One bar on the totals chart.
class SpendBucket {
  final DateTime start;
  final String label;
  final double total;

  const SpendBucket({
    required this.start,
    required this.label,
    required this.total,
  });
}

/// How the totals chart slices time.
enum SpendGranularity {
  day,
  week,
  month,
  year;

  int get defaultBuckets {
    switch (this) {
      case SpendGranularity.day:
        return 14;
      case SpendGranularity.week:
        return 12;
      case SpendGranularity.month:
        return 12;
      case SpendGranularity.year:
        return 5;
    }
  }

  String get noun {
    switch (this) {
      case SpendGranularity.day:
        return 'day';
      case SpendGranularity.week:
        return 'week';
      case SpendGranularity.month:
        return 'month';
      case SpendGranularity.year:
        return 'year';
    }
  }

  /// The start of the bucket [moment] falls in, [stepsBack] buckets earlier.
  ///
  /// Month and year steps go through DateTime's own normalisation (month 0 is
  /// last December), so month lengths and leap years are never hand-rolled.
  DateTime bucketStart(DateTime moment, {int stepsBack = 0}) {
    switch (this) {
      case SpendGranularity.day:
        final day = DateTime(moment.year, moment.month, moment.day);
        return day.subtract(Duration(days: stepsBack));
      case SpendGranularity.week:
        // Weeks start on Monday.
        final day = DateTime(moment.year, moment.month, moment.day);
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return monday.subtract(Duration(days: 7 * stepsBack));
      case SpendGranularity.month:
        return DateTime(moment.year, moment.month - stepsBack, 1);
      case SpendGranularity.year:
        return DateTime(moment.year - stepsBack, 1, 1);
    }
  }

  String label(DateTime start) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    switch (this) {
      case SpendGranularity.day:
        return '${start.day} ${months[start.month - 1]}';
      case SpendGranularity.week:
        return '${start.day} ${months[start.month - 1]}';
      case SpendGranularity.month:
        return months[start.month - 1];
      case SpendGranularity.year:
        return '${start.year}';
    }
  }
}
