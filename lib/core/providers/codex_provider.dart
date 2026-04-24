import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../services/burn_rate_calculator.dart';
import '../services/settings_service.dart';
import '../utils/home_paths.dart';
import '../utils/jsonl_reader.dart';
import '../utils/time_helpers.dart';
import 'usage_provider.dart';

/// Reads OpenAI Codex local session JSONL files (`~/.codex/sessions/**`).
/// Live token-refresh/quota endpoints from the Swift original are intentionally
/// dropped from this port — they require each platform's native keychain and
/// are fragile; traceLM sticks to the local-first path by default.
class CodexProvider implements UsageProvider {
  CodexProvider(this.settings);

  static const String id = 'codex';

  final SettingsService settings;
  final BurnRateCalculator _calc = BurnRateCalculator();

  @override
  String get identifier => id;
  @override
  String get displayName => 'Codex';
  @override
  ProviderCategory get category => ProviderCategory.api;

  @override
  bool get isEnabled => settings.providerEnabled(id);
  @override
  set isEnabled(bool value) => settings.setProviderEnabled(id, value);

  @override
  List<ProviderProfile> get profiles =>
      const [ProviderProfile(name: 'Default')];
  @override
  ProviderProfile? activeProfile = const ProviderProfile(name: 'Default');

  List<Directory> get _codexRoots {
    if (!HomePaths.supportsLocalFileScanning) return const [];
    final roots = <Directory>[];
    final env = HomePaths.env('CODEX_HOME');
    if (env != null) roots.add(Directory(env));
    final home = HomePaths.home;
    if (home != null) {
      roots.add(Directory(p.join(home, '.codex')));
      roots.add(Directory(p.join(home, '.config', 'codex')));
    }
    final seen = <String>{};
    return roots.where((d) => seen.add(d.absolute.path)).toList();
  }

  @override
  Future<bool> isAvailable() async {
    for (final root in _codexRoots) {
      if (await root.exists()) return true;
      final sessions = Directory(p.join(root.path, 'sessions'));
      if (await sessions.exists()) return true;
    }
    return false;
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
            message: 'Codex detected but no tokenized session data found yet.',
          ),
        ],
      );
    }

    // Many Codex local logs don't carry token counts — in that case, fall
    // back to request-count heuristics for a useful progress indicator.
    final hasTokenData =
        sessions.any((s) => s.totalTokens > 0 || s.costUSD > 0);
    if (hasTokenData) {
      return _calc.buildHeuristicResult(
        identifier: id,
        displayName: displayName,
        category: category,
        profile: activeProfile?.name ?? 'Default',
        sessions: sessions,
        source: DataSource.local,
      );
    }

    final heatmap = _calc.heatmapFromDailyValues(sessions
        .map((s) =>
            (date: s.startedAt, value: s.requestCount.clamp(1, 1 << 30).toDouble()))
        .toList());

    return ProviderResult(
      identifier: id,
      displayName: displayName,
      category: category,
      profile: activeProfile?.name ?? 'Default',
      windows: const [],
      today: _calc.todayUsage(sessions),
      burnRate: null,
      dailyHeatmap: heatmap,
      models: _calc.modelBreakdown(sessions),
      source: DataSource.local,
      freshness: DateTime.now(),
      warnings: [
        ProviderWarning(
          level: ProviderWarningLevel.info,
          message:
              'Codex logs do not include token counts — showing request-count history only.',
        ),
      ],
    );
  }

  @override
  Future<List<RawSession>> sessions({required DateTime since}) =>
      _loadSessions(since: since);

  Future<List<RawSession>> _loadSessions({required DateTime since}) async {
    final out = <RawSession>[];
    for (final root in _codexRoots) {
      final sessionsDir = Directory(p.join(root.path, 'sessions'));
      if (!await sessionsDir.exists()) continue;
      final files = await JsonlReader.collectJsonlFiles(sessionsDir);
      for (final file in files) {
        final rows = await JsonlReader.readObjects(file);
        for (final row in rows) {
          final s = _sessionFromRow(row, since: since);
          if (s != null) out.add(s);
        }
      }
    }
    out.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return out;
  }

  RawSession? _sessionFromRow(Map<String, dynamic> row,
      {required DateTime since}) {
    final nested = _nestedTokenCountSession(row, since: since);
    if (nested != null) return nested;

    final timestamp = TimeHelpers.parseISODate(
          asNonEmptyString(row['timestamp']),
        ) ??
        TimeHelpers.parseISODate(asNonEmptyString(row['created_at']));
    if (timestamp == null || timestamp.isBefore(since)) return null;

    final model = asNonEmptyString(row['model']) ?? 'codex';
    final input =
        asInt(row['input_tokens']) + asInt(row['prompt_tokens']);
    final output =
        asInt(row['output_tokens']) + asInt(row['completion_tokens']);
    final family = ModelFamily.resolve(model);

    return RawSession(
      providerIdentifier: id,
      profile: activeProfile?.name ?? 'Default',
      startedAt: timestamp,
      endedAt: timestamp,
      model: model,
      inputTokens: input,
      outputTokens: output,
      costUSD: family.pricing.totalCost(input: input, output: output),
    );
  }

  RawSession? _nestedTokenCountSession(
    Map<String, dynamic> row, {
    required DateTime since,
  }) {
    final payload = row['payload'];
    if (payload is! Map<String, dynamic>) return null;
    if (asNonEmptyString(payload['type']) != 'token_count') return null;
    final info = payload['info'];
    if (info is! Map<String, dynamic>) return null;
    final usage = (info['last_token_usage'] as Map<String, dynamic>?) ??
        (info['total_token_usage'] as Map<String, dynamic>?);
    if (usage == null) return null;
    final timestamp = TimeHelpers.parseISODate(
          asNonEmptyString(row['timestamp']),
        ) ??
        TimeHelpers.parseISODate(asNonEmptyString(payload['timestamp']));
    if (timestamp == null || timestamp.isBefore(since)) return null;

    final model = asNonEmptyString(payload['model']) ?? 'codex';
    final input = asInt(usage['input_tokens']);
    final cacheRead = asInt(usage['cached_input_tokens']);
    final output = asInt(usage['output_tokens']) +
        asInt(usage['reasoning_output_tokens']);
    final family = ModelFamily.resolve(model);

    return RawSession(
      providerIdentifier: id,
      profile: activeProfile?.name ?? 'Default',
      startedAt: timestamp,
      endedAt: timestamp,
      model: model,
      inputTokens: input,
      outputTokens: output,
      cacheReadTokens: cacheRead,
      costUSD: family.pricing.totalCost(
        input: input,
        output: output,
        cacheRead: cacheRead,
      ),
      projectHint: asNonEmptyString(payload['turn_id']),
    );
  }
}
