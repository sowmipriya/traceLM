import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../services/burn_rate_calculator.dart';
import '../services/settings_service.dart';
import '../utils/home_paths.dart';
import '../utils/jsonl_reader.dart';
import '../utils/time_helpers.dart';
import 'usage_provider.dart';

/// Cursor stores conversations in an app-local SQLite DB. A proper Dart
/// port would need `sqflite_common_ffi` for desktop. For the first iteration
/// we heuristic-detect Cursor's installation and report "detected, no local
/// tokenized data" rather than silently pretending usage is zero.
class CursorProvider implements UsageProvider {
  CursorProvider(this.settings);

  static const String id = 'cursor';

  final SettingsService settings;
  final BurnRateCalculator _calc = BurnRateCalculator();

  @override
  String get identifier => id;
  @override
  String get displayName => 'Cursor';
  @override
  ProviderCategory get category => ProviderCategory.subscription;

  @override
  bool get isEnabled => settings.providerEnabled(id);
  @override
  set isEnabled(bool value) => settings.setProviderEnabled(id, value);

  @override
  List<ProviderProfile> get profiles =>
      const [ProviderProfile(name: 'Default')];
  @override
  ProviderProfile? activeProfile = const ProviderProfile(name: 'Default');

  List<File> get _candidateMarkers {
    if (!HomePaths.supportsLocalFileScanning) return const [];
    final home = HomePaths.home;
    if (home == null) return const [];

    if (Platform.isMacOS) {
      return [
        File(p.join(home, 'Library', 'Application Support', 'Cursor',
            'User', 'settings.json')),
      ];
    }
    if (Platform.isWindows) {
      return [
        File(p.join(home, 'AppData', 'Roaming', 'Cursor', 'User',
            'settings.json')),
      ];
    }
    if (Platform.isLinux) {
      return [
        File(p.join(home, '.config', 'Cursor', 'User', 'settings.json')),
      ];
    }
    return const [];
  }

  @override
  Future<bool> isAvailable() async {
    for (final f in _candidateMarkers) {
      if (await f.exists()) return true;
    }
    return false;
  }

  @override
  Future<ProviderResult> probe() async {
    final rawSessions = await _loadSessions();
    if (rawSessions.isEmpty) {
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
                'Cursor detected. Open Sources settings and paste a session-export path to enable tracking.',
          ),
        ],
      );
    }
    return _calc.buildHeuristicResult(
      identifier: id,
      displayName: displayName,
      category: category,
      profile: activeProfile?.name ?? 'Default',
      sessions: rawSessions,
      source: DataSource.local,
    );
  }

  @override
  Future<List<RawSession>> sessions({required DateTime since}) =>
      _loadSessions(since: since);

  Future<List<RawSession>> _loadSessions({DateTime? since}) async {
    // Hook for users who export Cursor conversations to JSONL manually.
    final exportPath = settings.secret('cursor.exportPath');
    if (exportPath == null || exportPath.isEmpty) return const [];
    final file = File(exportPath);
    if (!await file.exists()) return const [];

    final sinceDate = since ?? DateTime.now().subtract(const Duration(days: 90));
    final rows = await JsonlReader.readObjects(file);
    final out = <RawSession>[];
    for (final row in rows) {
      final ts = TimeHelpers.parseISODate(asNonEmptyString(row['timestamp']));
      if (ts == null || ts.isBefore(sinceDate)) continue;
      final model = asNonEmptyString(row['model']) ?? 'cursor';
      final input = asInt(row['input_tokens']);
      final output = asInt(row['output_tokens']);
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
    out.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return out;
  }
}
