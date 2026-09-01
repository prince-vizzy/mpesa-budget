import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../state/category_store.dart';
import '../theme/app_colors.dart';

/// Total spend per period.
///
/// One series, so there is no legend — the heading says what is plotted. The
/// bars carry the only colour on the chart; gridlines and axis text stay
/// recessive, and only the largest bar is labelled. A value on every bar reads
/// as noise and gets ignored, so the axis and the tap tooltip carry the rest.
class TotalSpendChart extends StatelessWidget {
  final List<SpendBucket> buckets;
  final SpendGranularity granularity;

  const TotalSpendChart({
    super.key,
    required this.buckets,
    required this.granularity,
  });

  static String _money(double amount) {
    if (amount >= 1000000) {
      return 'Ksh ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      final thousands = amount / 1000;
      return 'Ksh ${thousands.toStringAsFixed(thousands >= 100 ? 0 : 1)}K';
    }
    return 'Ksh ${amount.toStringAsFixed(0)}';
  }

  /// A round number at or above the tallest bar, so the axis reads cleanly.
  static double _axisTop(double maxValue) {
    if (maxValue <= 0) return 100;
    final magnitude = <double>[1000000, 100000, 10000, 1000, 100, 10]
        .firstWhere((m) => maxValue >= m, orElse: () => 1);
    final step = magnitude / 2;
    return ((maxValue / step).ceil()) * step;
  }

  @override
  Widget build(BuildContext context) {
    final total = buckets.fold<double>(0, (sum, b) => sum + b.total);
    final maxValue = buckets.fold<double>(0, (m, b) => b.total > m ? b.total : m);
    final hasSpending = total > 0;

    // The one bar worth labelling directly.
    int peakIndex = 0;
    for (int i = 0; i < buckets.length; i++) {
      if (buckets[i].total > buckets[peakIndex].total) peakIndex = i;
    }

    final axisTop = _axisTop(maxValue);
    final average = buckets.isEmpty ? 0.0 : total / buckets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total spent',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _money(total),
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          hasSpending
              ? 'Across ${buckets.length} ${granularity.noun}s · '
                  '${_money(average)} per ${granularity.noun}'
              : 'Nothing recorded in the last ${buckets.length} '
                  '${granularity.noun}s',
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 190,
          child: !hasSpending
              ? const Center(
                  child: Text(
                    'No spending to chart yet',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                )
              : BarChart(
                  BarChartData(
                    maxY: axisTop,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: axisTop / 2,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppColors.lightShadow,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46,
                          interval: axisTop / 2,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                _money(value),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= buckets.length) {
                              return const SizedBox.shrink();
                            }
                            // With many bars, labelling every one turns the
                            // axis into a smear.
                            final stride = (buckets.length / 6).ceil();
                            if (buckets.length > 8 &&
                                i % stride != 0 &&
                                i != buckets.length - 1) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                buckets[i].label,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.componentBase,
                        tooltipBorderRadius: BorderRadius.circular(8),
                        getTooltipItem: (group, _, rod, __) {
                          final bucket = buckets[group.x];
                          return BarTooltipItem(
                            '${bucket.label}\n',
                            const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(
                                text: _money(rod.toY),
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < buckets.length; i++)
                        BarChartGroupData(
                          x: i,
                          showingTooltipIndicators: const [],
                          barRods: [
                            BarChartRodData(
                              toY: buckets[i].total,
                              width: buckets.length > 8 ? 10 : 18,
                              // Rounded at the data end, square on the baseline.
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              color: i == peakIndex
                                  ? AppColors.accent
                                  : AppColors.accent.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
        if (hasSpending) ...[
          const SizedBox(height: 8),
          Text(
            'Highest: ${buckets[peakIndex].label} · '
            '${_money(buckets[peakIndex].total)}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
