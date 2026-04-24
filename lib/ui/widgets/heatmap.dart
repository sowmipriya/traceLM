import 'package:flutter/material.dart';

import '../../core/models/daily_cell.dart';

class HeatmapWidget extends StatelessWidget {
  const HeatmapWidget({required this.cells, super.key});

  final List<DailyCell> cells;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(
            child: Text('No activity in the last 90 days',
                style: TextStyle(color: Colors.grey))),
      );
    }

    final weeks = <List<DailyCell>>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = (i + 7).clamp(0, cells.length);
      weeks.add(cells.sublist(i, end));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final cellSize =
          ((constraints.maxWidth - (weeks.length - 1) * 2) / weeks.length)
              .clamp(8.0, 18.0);
      return SizedBox(
        height: cellSize * 7 + 12,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final week in weeks)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Column(
                  children: [
                    for (final cell in week)
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: _colorFor(cell.intensity, context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Color _colorFor(UsageIntensity intensity, BuildContext ctx) {
    final base = Theme.of(ctx).colorScheme.primary;
    switch (intensity) {
      case UsageIntensity.zero:
        return Theme.of(ctx).colorScheme.surfaceContainerHighest;
      case UsageIntensity.low:
        return base.withOpacity(0.25);
      case UsageIntensity.medium:
        return base.withOpacity(0.5);
      case UsageIntensity.high:
        return base.withOpacity(0.75);
      case UsageIntensity.peak:
        return base;
    }
  }
}
