import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../services/burn_rate_calculator.dart';
import '../services/settings_service.dart';
import '../utils/home_paths.dart';
import '../utils/jsonl_reader.dart';
import '../utils/time_helpers.dart';
import 'usage_provider.dart';

/// Reads Gemini CLI telemetry from `~/.gemini/logs/*.jsonl` when present.
class GeminiProvider implements UsageProvider {
  GeminiProvider(this.settings);

  static const String id = 'gemini';

  final SettingsService settings;
  final BurnRateCalculator _calc = BurnRateCalculator();

  @override
  String get identifier => id;
  @override
  String get displayName => 'Gemini CLI';
  @override
  ProviderCategory get category => ProviderCategory.free;

  @override
  bool get isEnabled => settings.providerEnabled(id);
  @override
  set isEnabled(bool value) => settings.setProviderEnabled(id, value);

  @override
  List<ProviderProfile> get profiles =>
      const [ProviderProfile(name: 'Default')];
  @override
  ProviderProfile? activeProfile = const ProviderProfile(name: 'Default');

  Directory? get _root {
    if (!HomePaths.supportsLocalFileScanning) return null;
    final home = HomePaths.home;
    if (home == null) return null;
    return Directory(p.join(home, '.gemini'));
  }

  @override
  Future<bool> isAvailable() async {
    final root = _root;
    return root != null && await root.exists();
  }

  @override
  Future<ProviderResult> probe() async {
    final sessions = await _loadSessions(
        since: DateTime.now().subtract(const Duration(days: 90)));
    if (sessions.isEmpty) {
      return ProviderResult(
        identifier: id,
        displayName: displayName,
        category: category,
        profile: activeProfile?.name ?? 'Default',
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
            message:
                'Gemini CLI detected, but no tokenized session logs were found yet.',
          ),
        ],
      );
    }
    return _calc.buildHeuristicResult(
      identifier: id,
      displayName: displayName,
      category: category,
      profile: activeProfile?.name ?? 'Default',
      sessions: sessions,
      source: DataSource.local,
    );
  }

  @override
  Future<List<RawSession>> sessions({required DateTime since}) =>
      _loadSessions(since: since);

  Future<List<RawSession>> _loadSessions({required DateTime since}) async {
    final root = _root;
    if (root == null || !await root.exists()) return const [];
    final files = await JsonlReader.collectJsonlFiles(root);
    final out = <RawSession>[];
    for (final file in files) {
      final rows = await JsonlReader.readObjects(file);
      for (final row in rows) {
        final ts = TimeHelpers.parseISODate(asNonEmptyString(row['timestamp']));
        if (ts == null || ts.isBefore(since)) continue;
        final model = asNonEmptyString(row['model']) ?? 'gemini-pro';
        final input = asInt(row['input_tokens'] ?? row['prompt_tokens']);
        final output = asInt(row['output_tokens'] ?? row['completion_tokens']);
        final family = ModelFamily.resolve(model);
        out.add(RawSession(
          providerIdentifier: id,
          profile: activeProfile?.name ?? 'Default',
          startedAt: ts,
          endedAt: ts,
          model: model,
          inputTokens: input,
          outputTokens: output,
          costUSD: family.pricing.totalCost(input: input, output: output),
        ));
      }
    }
    out.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return out;
  }
}
