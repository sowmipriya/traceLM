import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../providers/provider_registry.dart';
import '../providers/usage_provider.dart';

/// The single hub every UI surface reads from. Holds the latest
/// [UsageSnapshot] and exposes a loading flag so refresh indicators can wire
/// up to it.
class UsageAggregator extends ChangeNotifier {
  UsageAggregator(this.registry);

  final ProviderRegistry registry;

  UsageSnapshot? _snapshot;
  bool _isRefreshing = false;
  DateTime? _lastRefreshedAt;

  UsageSnapshot? get snapshot => _snapshot;
  bool get isRefreshing => _isRefreshing;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;

  ProviderResult? resultFor(String id) =>
      _snapshot?.providers.firstWhere(
        (p) => p.identifier == id,
        orElse: () => ProviderResult.unavailable(
          identifier: id,
          displayName: id,
          category: ProviderCategory.subscription,
          warning: 'Provider not configured.',
        ),
      );

  /// Reconciles the current snapshot with the set of currently enabled
  /// providers. Adds optimistic "refreshing" placeholders so the UI doesn't
  /// flash empty when the user flips a provider on.
  void syncEnabledProviders() {
    final enabled = registry.enabledProviders();
    final enabledIds = enabled.map((p) => p.identifier).toSet();

    final existing = _snapshot;
    if (existing == null) {
      _snapshot = enabled.isEmpty
          ? null
          : UsageSnapshot.build(providers: enabled.map(_placeholder).toList());
      _lastRefreshedAt = _snapshot?.generatedAt;
      notifyListeners();
      return;
    }

    final visible =
        existing.providers.where((r) => enabledIds.contains(r.identifier)).toList();
    final existingIds = visible.map((r) => r.identifier).toSet();
    final pending =
        enabled.where((p) => !existingIds.contains(p.identifier)).toList();
    visible.addAll(pending.map(_placeholder));

    _snapshot = UsageSnapshot.build(
      generatedAt: existing.generatedAt,
      providers: visible,
    );
    _lastRefreshedAt = _snapshot?.generatedAt;
    notifyListeners();
  }

  /// Probes every enabled provider concurrently. Providers that time out or
  /// throw are recorded as `unavailable` placeholders — the UI renders their
  /// warning text rather than crashing the whole dashboard.
  Future<void> refresh({bool force = false}) async {
    if (_isRefreshing && !force) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      final providers = registry.enabledProviders();
      final futures = providers.map(_probeOne);
      final results = (await Future.wait(futures)).whereType<ProviderResult>();
      _snapshot = UsageSnapshot.build(providers: results.toList());
      _lastRefreshedAt = _snapshot?.generatedAt;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<ProviderResult?> _probeOne(UsageProvider provider) async {
    try {
      if (!await provider.isAvailable()) return null;
      return await provider.probe();
    } catch (e) {
      return ProviderResult.unavailable(
        identifier: provider.identifier,
        displayName: provider.displayName,
        category: provider.category,
        profile: provider.activeProfile?.name ?? 'Default',
        warning: e.toString(),
      );
    }
  }

  ProviderResult _placeholder(UsageProvider provider) => ProviderResult(
        identifier: provider.identifier,
        displayName: provider.displayName,
        category: provider.category,
        profile: provider.activeProfile?.name ?? 'Default',
        windows: const [],
        today: DailyUsage.zero,
        burnRate: null,
        dailyHeatmap: const [],
        models: const [],
        source: DataSource.local,
        freshness: DateTime.now(),
        warnings: [
          ProviderWarning(
            level: ProviderWarningLevel.info,
            message: 'Enabled. Refreshing usage data now.',
          ),
        ],
      );
}
