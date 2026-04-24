import 'provider_result.dart';

class UsageSummary {
  const UsageSummary({
    required this.worstPercentage,
    required this.worstProvider,
    required this.worstWindow,
    required this.totalCostTodayUSD,
    required this.totalTokensToday,
    required this.totalRequestsToday,
  });

  final double worstPercentage;
  final String? worstProvider;
  final String? worstWindow;
  final double totalCostTodayUSD;
  final int totalTokensToday;
  final int totalRequestsToday;
}

class UsageSnapshot {
  const UsageSnapshot({
    required this.generatedAt,
    required this.providers,
    required this.summary,
  });

  final DateTime generatedAt;
  final List<ProviderResult> providers;
  final UsageSummary summary;

  static UsageSnapshot build({
    DateTime? generatedAt,
    required List<ProviderResult> providers,
  }) {
    final visible = providers.where((p) => !p.isUnavailable).toList()
      ..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    String? worstProvider;
    String? worstWindow;
    double worstPercentage = 0;
    for (final p in visible) {
      final w = p.primaryWindow;
      if (w == null) continue;
      if (w.percentage > worstPercentage) {
        worstPercentage = w.percentage;
        worstProvider = p.identifier;
        worstWindow = w.kind.reportingKey;
      }
    }

    double totalCost = 0;
    int totalTokens = 0;
    int totalRequests = 0;
    for (final p in visible) {
      totalCost += p.today.costUSD;
      totalTokens += p.today.tokens;
      totalRequests += p.today.requests;
    }

    return UsageSnapshot(
      generatedAt: generatedAt ?? DateTime.now(),
      providers: visible,
      summary: UsageSummary(
        worstPercentage: worstPercentage,
        worstProvider: worstProvider,
        worstWindow: worstWindow,
        totalCostTodayUSD: totalCost,
        totalTokensToday: totalTokens,
        totalRequestsToday: totalRequests,
      ),
    );
  }
}
