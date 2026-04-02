import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../state/category_store.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../widgets/frequency_loader.dart';
import '../widgets/premium_ui.dart';

enum TimeRange { daily, weekly, monthly, annually }
enum ChartMode { trend, category }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  TimeRange _selectedRange = TimeRange.daily;
  ChartMode _chartMode = ChartMode.trend;
  String _categoryQuery = '';
  Future<Map<String, List<double>>>? _trendFuture;
  Future<Map<String, double>>? _usageFuture;
  Future<List<Transaction>>? _transactionsFuture;
  Set<String> _enabledCategories = {};
  Set<String> _visibleCategories = {};
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData(resetToggles: true);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, List<double>>> _getTrendData(CategoryStore store) {
    switch (_selectedRange) {
      case TimeRange.daily:
        return store.getCategoryTrendSeries(
          bucketCount: 30,
          bucketSize: const Duration(days: 1),
        );
      case TimeRange.weekly:
        return store.getCategoryTrendSeries(
          bucketCount: 12,
          bucketSize: const Duration(days: 7),
        );
      case TimeRange.monthly:
        return store.getCategoryTrendSeries(
          bucketCount: 12,
          bucketSize: const Duration(days: 30),
        );
      case TimeRange.annually:
        return store.getCategoryTrendSeries(
          bucketCount: 5,
          bucketSize: const Duration(days: 365),
        );
    }
  }

  String _getChartTitle() {
    if (_chartMode == ChartMode.category) {
      switch (_selectedRange) {
        case TimeRange.daily:
          return 'Category Usage (Last 30 Days)';
        case TimeRange.weekly:
          return 'Category Usage (Last 12 Weeks)';
        case TimeRange.monthly:
          return 'Category Usage (Last 12 Months)';
        case TimeRange.annually:
          return 'Category Usage (Last 5 Years)';
      }
    }

    switch (_selectedRange) {
      case TimeRange.daily:
        return 'Spending Trend (Last 30 Days)';
      case TimeRange.weekly:
        return 'Spending Trend (Last 12 Weeks)';
      case TimeRange.monthly:
        return 'Spending Trend (Last 12 Months)';
      case TimeRange.annually:
        return 'Spending Trend (Last 5 Years)';
    }
  }

  int _getDurationDays() {
    switch (_selectedRange) {
      case TimeRange.daily:
        return 30;
      case TimeRange.weekly:
        return 7 * 12;
      case TimeRange.monthly:
        return 30 * 12;
      case TimeRange.annually:
        return 365 * 5;
    }
  }

  void _reloadData({bool resetToggles = false}) {
    final store = context.read<CategoryStore>();
    _transactionsFuture = store.getAllCategorizedTransactions();

    if (_chartMode == ChartMode.trend) {
      _trendFuture = _getTrendData(store);
      _trendFuture!.then((data) {
        if (!mounted) return;
        final keys = <String>{
          ...store.categories.map((c) => c.name),
          ...data.entries
              .where((e) => e.value.any((v) => v > 0))
              .map((e) => e.key),
        }.toList()
          ..sort();

        if (resetToggles) {
          _enabledCategories = <String>{};
        } else {
          _enabledCategories =
              _enabledCategories.where((c) => keys.contains(c)).toSet();
        }
        _startStaggeredReveal(keys);
      });
    } else {
      _usageFuture = store.getCategorySpendingData(_getDurationDays());
    }

    setState(() {});
  }

  void _startStaggeredReveal(List<String> allKeys) {
    _revealTimer?.cancel();
    final queue = allKeys.where((k) => _enabledCategories.contains(k)).toList();
    _visibleCategories = {};
    if (queue.isEmpty) {
      setState(() {});
      return;
    }
    int index = 0;
    _visibleCategories.add(queue[index]);
    setState(() {});
    index++;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      if (!mounted || index >= queue.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _visibleCategories.add(queue[index]);
      });
      index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CategoryStore>();

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Container(
          color: const Color(0xFF0A1B4A),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1B4A),
                borderRadius: BorderRadius.circular(31),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.darkShadow,
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Spending History',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1B4A),
              AppColors.mainBackground,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* ================= TIME RANGE ================= */

            GlassPanel(
              padding: const EdgeInsets.all(8),
              child: ToggleButtons(
                isSelected: TimeRange.values
                    .map((r) => r == _selectedRange)
                    .toList(),
                onPressed: (i) {
                  setState(() => _selectedRange = TimeRange.values[i]);
                  _reloadData();
                },
                borderRadius: BorderRadius.circular(12),
                fillColor: AppColors.accent,
                selectedColor: AppColors.darkShadow,
                color: AppColors.secondaryText,
                children: const [
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Daily')),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Weekly')),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Monthly')),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Annual')),
                ],
              ),
            ),

            const SizedBox(height: 24),

            GlassPanel(
              padding: const EdgeInsets.all(8),
              child: ToggleButtons(
                isSelected: [
                  _chartMode == ChartMode.trend,
                  _chartMode == ChartMode.category,
                ],
                onPressed: (index) {
                  setState(() {
                    _chartMode = index == 0 ? ChartMode.trend : ChartMode.category;
                  });
                  _reloadData();
                },
                borderRadius: BorderRadius.circular(12),
                fillColor: AppColors.accent,
                selectedColor: AppColors.darkShadow,
                color: AppColors.secondaryText,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Trend'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('By Category'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /* ================= CHART ================= */

            Text(
              _getChartTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),

            if (_chartMode == ChartMode.category) ...[
              TextField(
                onChanged: (value) {
                  setState(() {
                    _categoryQuery = value.trim();
                  });
                },
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: 'Search category...',
                  hintStyle: const TextStyle(color: AppColors.secondaryText),
                  prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.componentBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 300,
              child: _chartMode == ChartMode.category
                  ? FutureBuilder<Map<String, double>>(
                      future: _usageFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: FrequencyLoader());
                        }
                        return CategoryUsageChart(
                          categorySpendingMap: snapshot.data!,
                          query: _categoryQuery,
                        );
                      },
                    )
                  : FutureBuilder<Map<String, List<double>>>(
                      future: _trendFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: FrequencyLoader());
                        }
                        return SpendingChart(
                          categorySeries: snapshot.data!,
                          categoryNames: store.categories.map((c) => c.name).toList(),
                          timeRange: _selectedRange,
                          enabledCategories: _enabledCategories,
                          visibleCategories: _visibleCategories,
                          onToggleCategory: (category, enabled) {
                            setState(() {
                              if (enabled) {
                                _enabledCategories.add(category);
                                _visibleCategories.add(category);
                              } else {
                                _enabledCategories.remove(category);
                                _visibleCategories.remove(category);
                              }
                            });
                          },
                        );
                      },
                    ),
              ),
            ),

            const SizedBox(height: 24),

            /* ================= TRANSACTIONS ================= */

            const Text(
              'All Categorized Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Transaction>>(
              future: _transactionsFuture,
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transactions found',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  );
                }

                final transactions = snap.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length > 120 ? 120 : transactions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.lightShadow),
                  itemBuilder: (_, i) {
                    final tx = transactions[i];
                    return ListTile(
                      title: Text(
                        tx.description,
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, y').format(tx.date),
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                      trailing: Text(
                        'Ksh ${tx.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/* =========================================================
   CHART
========================================================= */

class SpendingChart extends StatelessWidget {
  final Map<String, List<double>> categorySeries;
  final List<String> categoryNames;
  final TimeRange timeRange;
  final Set<String> enabledCategories;
  final Set<String> visibleCategories;
  final void Function(String category, bool enabled) onToggleCategory;

  const SpendingChart({
    super.key,
    required this.categorySeries,
    required this.categoryNames,
    required this.timeRange,
    required this.enabledCategories,
    required this.visibleCategories,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    const lineColors = <Color>[
      AppColors.accent,
      Color(0xFFE59F00),
      Color(0xFFCC8D00),
      Color(0xFFB37B00),
      Color(0xFFFFC033),
      Color(0xFFD99700),
      Color(0xFFBF8500),
      Color(0xFFA67300),
    ];

    final entries = categorySeries.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold<double>(0, (sum, v) => sum + v);
        final bTotal = b.value.fold<double>(0, (sum, v) => sum + v);
        return bTotal.compareTo(aTotal);
      });
    final seen = <String>{};
    final allEntries = <MapEntry<String, List<double>>>[
      ...entries.where((e) => seen.add(e.key)),
      ...categoryNames
          .where((name) => seen.add(name))
          .map((name) => MapEntry(name, const <double>[])),
    ];
    final visibleEntries = allEntries
        .where((e) => enabledCategories.contains(e.key))
        .where((e) => visibleCategories.contains(e.key))
        .where((e) => e.value.isNotEmpty)
        .toList();

    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < allEntries.length; i++)
              FilterChip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                selectedColor: lineColors[i % lineColors.length].withValues(alpha: 0.25),
                backgroundColor: AppColors.lightShadow,
                labelStyle: TextStyle(
                  color: enabledCategories.contains(allEntries[i].key)
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                  fontSize: 11,
                ),
                selected: enabledCategories.contains(allEntries[i].key),
                onSelected: (selected) => onToggleCategory(allEntries[i].key, selected),
                label: Text(allEntries[i].key),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Builder(
            builder: (context) {
              if (allEntries.isEmpty) {
                return const Center(
                  child: Text(
                    'No categories available yet',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                );
              }
              if (enabledCategories.isEmpty) {
                return const Center(
                  child: Text(
                    'Select categories to show trend lines',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                );
              }
              if (visibleEntries.isEmpty) {
                return const Center(
                  child: Text(
                    'Waiting for selected categories to reveal...',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                );
              }

              final maxX = (visibleEntries.first.value.length - 1).toDouble();
              double maxY = 100;
              for (final entry in visibleEntries) {
                for (final value in entry.value) {
                  if (value > maxY) maxY = value;
                }
              }

              return LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY * 1.2,
                  lineBarsData: [
                    for (int i = 0; i < visibleEntries.length; i++)
                      LineChartBarData(
                        spots: visibleEntries[i]
                            .value
                            .asMap()
                            .entries
                            .map((point) => FlSpot(point.key.toDouble(), point.value))
                            .toList(),
                        isCurved: true,
                        barWidth: 2.5,
                        color: lineColors[i % lineColors.length],
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (maxX / 4).clamp(1, 10).toDouble(),
                        getTitlesWidget: (value, _) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: ((maxY * 1.2) / 4).clamp(50, 20000).toDouble(),
                        getTitlesWidget: (value, _) => Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}K'
                              : value.toInt().toString(),
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.lightShadow, strokeWidth: 1),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CategoryUsageChart extends StatelessWidget {
  final Map<String, double> categorySpendingMap;
  final String query;

  const CategoryUsageChart({
    super.key,
    required this.categorySpendingMap,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    if (categorySpendingMap.isEmpty ||
        categorySpendingMap.values.every((value) => value <= 0)) {
      return const Center(
        child: Text(
          'No category usage data available',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    final normalizedQuery = query.toLowerCase();
    final entries = categorySpendingMap.entries
        .where((entry) => entry.key.toLowerCase().contains(normalizedQuery))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No matching categories',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    final maxAmount = entries.first.value;
    final totalAmount = entries.fold<double>(0, (sum, entry) => sum + entry.value);

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final ratio = maxAmount == 0 ? 0.0 : entry.value / maxAmount;
        final percent = totalAmount == 0 ? 0.0 : (entry.value / totalAmount) * 100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Ksh ${entry.value.toStringAsFixed(0)} (${percent.toStringAsFixed(0)}%)',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: ratio,
                backgroundColor: AppColors.lightShadow,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ],
        );
      },
    );
  }
}
