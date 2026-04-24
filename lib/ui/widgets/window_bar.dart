import 'package:flutter/material.dart';

import '../../core/models/usage_window.dart';
import '../../core/utils/time_helpers.dart';

class WindowProgressBar extends StatelessWidget {
  const WindowProgressBar({required this.window, super.key});

  final UsageWindow window;

  @override
  Widget build(BuildContext context) {
    final color = _color(window.percentage, context);
    final reset = TimeHelpers.relativeResetString(window.resetAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(window.kind.title,
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text('${window.percentage.round()}%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (window.percentage / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(_usedLabel(window),
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            if (reset != null)
              Text('resets in $reset',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (window.forecast != null) ...[
          const SizedBox(height: 2),
          Text(
            _forecastLabel(window),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: _forecastColor(window, context)),
          ),
        ],
      ],
    );
  }

  String _usedLabel(UsageWindow w) {
    final used = w.used.round();
    final limit = w.limit?.round();
    final unit = switch (w.unit) {
      UsageUnit.tokens => 'tokens',
      UsageUnit.requests => 'requests',
      UsageUnit.credits => 'credits',
      UsageUnit.dollars => 'USD',
    };
    if (limit == null) return '$used $unit';
    return '$used / $limit $unit';
  }

  String _forecastLabel(UsageWindow w) {
    final f = w.forecast!;
    final pct = f.projectedPercentageAtReset.round();
    switch (f.status) {
      case ForecastStatus.onTrack:
        return 'On track — projected $pct% at reset';
      case ForecastStatus.tight:
        return 'Tight — projected $pct% at reset';
      case ForecastStatus.willExceed:
        final eta = f.timeToDepletion;
        if (eta != null) {
          final mins = eta.inMinutes;
          return 'Will exceed — quota out in ~${mins}m';
        }
        return 'Will exceed — projected $pct% at reset';
    }
  }

  Color _forecastColor(UsageWindow w, BuildContext ctx) {
    switch (w.forecast!.status) {
      case ForecastStatus.onTrack:
        return Colors.green.shade600;
      case ForecastStatus.tight:
        return Colors.orange.shade600;
      case ForecastStatus.willExceed:
        return Colors.red.shade600;
    }
  }

  Color _color(double pct, BuildContext ctx) {
    if (pct < 60) return Colors.green.shade600;
    if (pct < 85) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}
