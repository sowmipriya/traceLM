import 'burn_rate.dart';
import 'daily_cell.dart';
import 'usage_window.dart';

enum ProviderCategory {
  subscription('Subscription'),
  api('API'),
  usageBased('Usage Based'),
  free('Free');

  const ProviderCategory(this.title);
  final String title;
}

enum DataSource { local, api, mixed }

enum ProviderWarningLevel { info, warning, critical }

class ProviderWarning {
  ProviderWarning({required this.level, required this.message});
  final ProviderWarningLevel level;
  final String message;
}

class DailyUsage {
  const DailyUsage({
    this.costUSD = 0,
    this.tokens = 0,
    this.requests = 0,
  });

  final double costUSD;
  final int tokens;
  final int requests;

  static const DailyUsage zero = DailyUsage();
}

class ModelBreakdown {
  const ModelBreakdown({
    required this.model,
    required this.tokens,
    required this.requests,
    required this.costUSD,
  });

  final String model;
  final int tokens;
  final int requests;
  final double costUSD;
}

class ProviderResult {
  ProviderResult({
    required this.identifier,
    required this.displayName,
    required this.category,
    required this.profile,
    required this.windows,
    required this.today,
    required this.burnRate,
    required this.dailyHeatmap,
    required this.models,
    required this.source,
    required this.freshness,
    required this.warnings,
  });

  final String identifier;
  final String displayName;
  final ProviderCategory category;
  final String profile;
  final List<UsageWindow> windows;
  final DailyUsage today;
  final BurnRate? burnRate;
  final List<DailyCell> dailyHeatmap;
  final List<ModelBreakdown> models;
  final DataSource source;
  final DateTime freshness;
  final List<ProviderWarning> warnings;

  String get id => '$identifier:$profile';

  UsageWindow? get primaryWindow {
    if (windows.isEmpty) return null;
    return windows.reduce((a, b) => a.percentage >= b.percentage ? a : b);
  }

  bool get isStale =>
      DateTime.now().difference(freshness) > const Duration(minutes: 10);

  bool get isUnavailable => freshness.millisecondsSinceEpoch == 0;

  factory ProviderResult.unavailable({
    required String identifier,
    required String displayName,
    required ProviderCategory category,
    String profile = 'Default',
    required String warning,
  }) =>
      ProviderResult(
        identifier: identifier,
        displayName: displayName,
        category: category,
        profile: profile,
        windows: const [],
        today: DailyUsage.zero,
        burnRate: null,
        dailyHeatmap: const [],
        models: const [],
        source: DataSource.local,
        freshness: DateTime.fromMillisecondsSinceEpoch(0),
        warnings: [
          ProviderWarning(level: ProviderWarningLevel.warning, message: warning)
        ],
      );
}
