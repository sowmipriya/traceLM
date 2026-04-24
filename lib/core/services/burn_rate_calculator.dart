import '../models/burn_rate.dart';
import '../models/daily_cell.dart';
import '../models/provider_result.dart';
import '../models/raw_session.dart';
import '../models/usage_window.dart';
import '../utils/time_helpers.dart';

/// Heuristic window limits are inferred from the 90th percentile of rolling
/// usage samples across the provided sessions. When the user has no declared
/// limit (Claude subscription, free tier, etc.), this keeps a useful progress
/// indicator instead of showing 0/0.
class BurnRateCalculator {
  ProviderResult buildHeuristicResult({
    required String identifier,
    required String displayName,
    required ProviderCategory category,
    required String profile,
    required List<RawSession> sessions,
    required DataSource source,
    List<ProviderWarning> warnings = const [],
  }) {
    final fiveHour = _makeHeuristicWindow(
      kind: const WindowKind.fiveHour(),
      duration: SessionWindowPreset.lastFiveHours,
      sessions: sessions,
      unit: UsageUnit.tokens,
    );
    final weekly = _makeHeuristicWindow(
      kind: const WindowKind.weekly(),
      duration: SessionWindowPreset.lastSevenDays,
      sessions: sessions,
      unit: UsageUnit.tokens,
    );
    final monthly = _makeHeuristicWindow(
      kind: const WindowKind.monthly(),
      duration: SessionWindowPreset.lastThirtyDays,
      sessions: sessions,
      unit: UsageUnit.tokens,
    );

    return ProviderResult(
      identifier: identifier,
      displayName: displayName,
      category: category,
      profile: profile,
      windows: [fiveHour, weekly, monthly].whereType<UsageWindow>().toList(),
      today: todayUsage(sessions),
      burnRate: burnRate(sessions: sessions, activeWindow: fiveHour),
      dailyHeatmap: heatmap(sessions),
      models: modelBreakdown(sessions),
      source: source,
      freshness: DateTime.now(),
      warnings: warnings,
    );
  }

  DailyUsage todayUsage(List<RawSession> sessions) {
    final todayStart = TimeHelpers.startOfDay(DateTime.now());
    final today = sessions.where((s) => !s.startedAt.isBefore(todayStart));
    double cost = 0;
    int tokens = 0;
    int requests = 0;
    for (final s in today) {
      cost += s.costUSD;
      tokens += s.totalTokens;
      requests += s.requestCount < 1 ? 1 : s.requestCount;
    }
    return DailyUsage(costUSD: cost, tokens: tokens, requests: requests);
  }

  List<ModelBreakdown> modelBreakdown(List<RawSession> sessions) {
    final grouped = <String, List<RawSession>>{};
    for (final s in sessions) {
      grouped.putIfAbsent(s.model, () => []).add(s);
    }
    final out = grouped.entries.map((e) {
      int tokens = 0;
      int requests = 0;
      double cost = 0;
      for (final s in e.value) {
        tokens += s.totalTokens;
        requests += s.requestCount;
        cost += s.costUSD;
      }
      return ModelBreakdown(
        model: e.key,
        tokens: tokens,
        requests: requests,
        costUSD: cost,
      );
    }).toList()
      ..sort((a, b) => b.tokens.compareTo(a.tokens));
    return out;
  }

  List<DailyCell> heatmap(List<RawSession> sessions, {int days = 90}) {
    final start = TimeHelpers.startOfDay(
        DateTime.now().subtract(Duration(days: days - 1)));
    final totals = <String, double>{};
    for (final s in sessions.where((s) => !s.startedAt.isBefore(start))) {
      final key =
          TimeHelpers.dayFormatter.format(TimeHelpers.startOfDay(s.startedAt));
      totals[key] = (totals[key] ?? 0) + _metric(s);
    }
    final maxValue =
        totals.values.isEmpty ? 0.0 : totals.values.reduce((a, b) => a > b ? a : b);

    return List.generate(days, (offset) {
      final date = start.add(Duration(days: offset));
      final key = TimeHelpers.dayFormatter.format(date);
      final value = totals[key] ?? 0;
      return DailyCell(
        date: date,
        value: value,
        intensity: DailyCell.intensityFor(value, maxValue),
      );
    });
  }

  List<DailyCell> heatmapFromDailyValues(
    List<({DateTime date, double value})> values, {
    int days = 90,
  }) {
    final start = TimeHelpers.startOfDay(
        DateTime.now().subtract(Duration(days: days - 1)));
    final totals = <String, double>{};
    for (final e in values.where((e) => !e.date.isBefore(start))) {
      final key =
          TimeHelpers.dayFormatter.format(TimeHelpers.startOfDay(e.date));
      totals[key] =
          (totals[key] ?? 0) + (e.value < 0 ? 0 : e.value);
    }
    final maxValue = totals.values.isEmpty
        ? 0.0
        : totals.values.reduce((a, b) => a > b ? a : b);

    return List.generate(days, (offset) {
      final date = start.add(Duration(days: offset));
      final key = TimeHelpers.dayFormatter.format(date);
      final value = totals[key] ?? 0;
      return DailyCell(
        date: date,
        value: value,
        intensity: DailyCell.intensityFor(value, maxValue),
      );
    });
  }

  BurnRate? burnRate({
    required List<RawSession> sessions,
    UsageWindow? activeWindow,
  }) {
    final since =
        DateTime.now().subtract(SessionWindowPreset.lastThirtyMinutes);
    final recent = sessions.where((s) => !s.startedAt.isBefore(since)).toList();
    if (recent.isEmpty) return null;

    final tokens = recent.fold<int>(0, (sum, s) => sum + s.totalTokens);
    if (tokens <= 0) return null;

    final cost = recent.fold<double>(0, (sum, s) => sum + s.costUSD);
    final earliest = recent
        .map((s) => s.startedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final minutes = DateTime.now().difference(earliest).inSeconds / 60;
    final boundedMinutes = minutes.clamp(1.0, 30.0);
    final tokensPerMinute = tokens / boundedMinutes;
    final costPerHour = (cost / boundedMinutes) * 60;

    int? projectedTokens;
    double? projectedCost;
    int? remainingMinutes;

    final resetAt = activeWindow?.resetAt;
    if (resetAt != null) {
      final remaining =
          resetAt.difference(DateTime.now()).inMinutes.clamp(0, 1 << 30);
      remainingMinutes = remaining;
      final used = activeWindow?.used;
      if (used != null) {
        projectedTokens = (used + (tokensPerMinute * remaining)).round();
      }
      projectedCost = cost + ((costPerHour / 60) * remaining);
    }

    return BurnRate(
      tokensPerMinute: tokensPerMinute,
      costPerHour: costPerHour,
      projectedTotalTokens: projectedTokens,
      projectedTotalCost: projectedCost,
      remainingMinutes: remainingMinutes,
    );
  }

  UsageWindow? _makeHeuristicWindow({
    required WindowKind kind,
    required Duration duration,
    required List<RawSession> sessions,
    required UsageUnit unit,
  }) {
    if (sessions.isEmpty) return null;
    final now = DateTime.now();
    final since = now.subtract(duration);
    final current = sessions.where((s) => !s.startedAt.isBefore(since)).toList();

    final currentUsed =
        current.fold<int>(0, (sum, s) => sum + s.totalTokens).toDouble();
    final samples = _rollingSamples(sessions, duration);
    final inferredLimit = _percentile90(samples) ??
        (currentUsed * 1.25 > 1 ? currentUsed * 1.25 : 1);
    final percentage = inferredLimit > 0
        ? ((currentUsed / inferredLimit) * 100).clamp(0.0, 100.0)
        : 0.0;
    final earliestCurrent = current.isEmpty
        ? null
        : current.map((s) => s.startedAt).reduce(
            (a, b) => a.isBefore(b) ? a : b);
    final resetAt = earliestCurrent == null
        ? now.add(duration)
        : earliestCurrent.add(duration);

    return UsageWindow(
      kind: kind,
      used: currentUsed,
      limit: inferredLimit,
      unit: unit,
      percentage: percentage,
      resetAt: resetAt,
    );
  }

  List<double> _rollingSamples(List<RawSession> sessions, Duration duration) {
    if (sessions.isEmpty) return const [];
    final sorted = [...sessions]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    return sorted.map((anchor) {
      final rangeStart = anchor.startedAt.subtract(duration);
      int total = 0;
      for (final s in sorted) {
        if (!s.startedAt.isBefore(rangeStart) &&
            !s.startedAt.isAfter(anchor.startedAt)) {
          total += s.totalTokens;
        }
      }
      return total.toDouble();
    }).toList();
  }

  double? _percentile90(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * 0.9).floor();
    final v = sorted[index];
    return v < 1 ? 1 : v;
  }

  double _metric(RawSession s) {
    final tokens = s.totalTokens.toDouble();
    return s.costUSD > tokens ? s.costUSD : tokens;
  }
}
