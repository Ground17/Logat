import 'package:flutter/material.dart';
import '../models/daily_stats.dart';

class HeatmapWidget extends StatelessWidget {
  const HeatmapWidget({
    super.key,
    required this.stats,
    this.onDayTap,
  });

  final List<DailyStats> stats;
  final void Function(DateTime day)? onDayTap;

  static const double _cellSize = 12.0;
  static const double _cellGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsByDay = {for (final s in stats) _dayKey(s.day): s};

    // Build grid aligned to Sunday-start weeks
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    // Go back 52 weeks from start of this week
    final startOfThisWeek =
        today.subtract(Duration(days: today.weekday % 7)); // Sunday
    final gridStart = startOfThisWeek.subtract(const Duration(days: 51 * 7));

    final totalDays = today.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels
          _MonthLabels(
            gridStart: gridStart,
            totalWeeks: totalWeeks,
            cellSize: _cellSize,
            cellGap: _cellGap,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(totalWeeks, (weekIndex) {
              return Column(
                children: List.generate(7, (dayOfWeek) {
                  final date = gridStart
                      .add(Duration(days: weekIndex * 7 + dayOfWeek));
                  if (date.isAfter(today)) {
                    return SizedBox(
                        width: _cellSize + _cellGap,
                        height: _cellSize + _cellGap);
                  }
                  final key = _dayKey(date);
                  final s = statsByDay[key];
                  final count = s?.assetCount ?? 0;
                  final color = _cellColor(count, isDark);

                  return GestureDetector(
                    onTap: () => onDayTap?.call(date),
                    child: Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.all(_cellGap / 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
          const SizedBox(height: 4),
          _Legend(isDark: isDark),
        ],
      ),
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _cellColor(int count, bool isDark) {
    if (count == 0) {
      return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    } else if (count <= 3) {
      return isDark ? const Color(0xFF26A641) : const Color(0xFF9BE9A8);
    } else if (count <= 9) {
      return isDark ? const Color(0xFF2EA043) : const Color(0xFF40C463);
    } else {
      return isDark ? const Color(0xFF39D353) : const Color(0xFF216E39);
    }
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.gridStart,
    required this.totalWeeks,
    required this.cellSize,
    required this.cellGap,
  });

  final DateTime gridStart;
  final int totalWeeks;
  final double cellSize;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final labels = <Widget>[];
    int? lastMonth;

    for (var week = 0; week < totalWeeks; week++) {
      final weekStart = gridStart.add(Duration(days: week * 7));
      final month = weekStart.month;
      if (month != lastMonth) {
        lastMonth = month;
        labels.add(SizedBox(
          width: cellSize + cellGap,
          child: Text(
            _monthAbbr(month),
            style: const TextStyle(fontSize: 9),
            overflow: TextOverflow.visible,
          ),
        ));
      } else {
        labels.add(SizedBox(width: cellSize + cellGap));
      }
    }

    return Row(children: labels);
  }

  String _monthAbbr(int month) {
    const abbrs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return abbrs[month - 1];
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [
            Colors.grey.shade800,
            const Color(0xFF9BE9A8),
            const Color(0xFF40C463),
            const Color(0xFF39D353),
          ]
        : [
            Colors.grey.shade200,
            const Color(0xFF9BE9A8),
            const Color(0xFF40C463),
            const Color(0xFF216E39),
          ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Less', style: TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        ...colors.map((c) => Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
        const SizedBox(width: 4),
        const Text('More', style: TextStyle(fontSize: 10)),
      ],
    );
  }
}
