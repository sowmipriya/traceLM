import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../services/burn_rate_calculator.dart';
import '../services/settings_service.dart';
import '../utils/home_paths.dart';
import '../utils/jsonl_reader.dart';
import '../utils/time_helpers.dart';
import 'usage_provider.dart';

/// Reads Claude Code's local `~/.claude/projects/**/.jsonl` session files.
class ClaudeCodeProvider implements UsageProvider {
  ClaudeCodeProvider(this.settings);

  static const String id = 'claude-code';

  final SettingsService settings;
  final BurnRateCalculator _calc = BurnRateCalculator();

  @override
  String get identifier => id;

  @override
  String get displayName => 'Claude Code';

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

  List<Directory> get _claudeRoots {
    if (!HomePaths.supportsLocalFileScanning) return const [];
    final override = HomePaths.env('CLAUDE_CONFIG_DIR');
    if (override != null) {
      return override
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((path) {
        final expanded = path.startsWith('~')
            ? p.join(HomePaths.home ?? '', path.substring(1))
            : path;
        final dir = Directory(expanded);
        if (p.basename(dir.path) == 'projects') {
          return dir.parent;
        }
        return dir;
      }).toList();
    }
    final home = HomePaths.home;
    if (home == null) return const [];
    return [
      Directory(p.join(home, '.config', 'claude')),
      Directory(p.join(home, '.claude')),
    ];
  }

  List<Directory> get _projectDirectories =>
      _claudeRoots.map((r) => Directory(p.join(r.path, 'projects'))).toList();

  List<File> get _historyFiles =>
      _claudeRoots.map((r) => File(p.join(r.path, 'history.jsonl'))).toList();

  @override
  Future<bool> isAvailable() async {
    if (!HomePaths.supportsLocalFileScanning) return false;
    for (final dir in [..._claudeRoots, ..._projectDirectories]) {
      if (await dir.exists()) return true;
    }
    for (final file in _historyFiles) {
      if (await file.exists()) return true;
    }
    return false;
  }

  @override
  Future<ProviderResult> probe() async {
    final since = DateTime.now().subtract(const Duration(days: 90));
    final sessions = await _loadSessions(since: since);
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
                'Claude Code detected, but no tokenized session files were found yet.',
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
    final out = <RawSession>[];
    final seen = <String>{};
    for (final dir in _projectDirectories) {
      if (!await dir.exists()) continue;
      final files = await JsonlReader.collectJsonlFiles(dir);
      for (final file in files) {
        if (!seen.add(file.absolute.path)) continue;
        final rows = await JsonlReader.readObjects(file);
        for (final row in rows) {
          final session = _sessionFromRow(row, since: since);
          if (session != null) out.add(session);
        }
      }
    }

    if (out.isEmpty) {
      out.addAll(await _fallbackHistorySessions(since: since));
    }

    out.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return out;
  }

  RawSession? _sessionFromRow(
    Map<String, dynamic> row, {
    required DateTime since,
  }) {
    final timestamp =
        TimeHelpers.parseISODate(asNonEmptyString(row['timestamp']));
    if (timestamp == null || timestamp.isBefore(since)) return null;

    final usage = _usagePayload(row);
    if (usage == null) return null;

    final model = _modelName(row) ?? 'Claude';
    final input = asInt(usage['input_tokens']);
    final output = asInt(usage['output_tokens']);
    final cacheRead = asInt(usage['cache_read_input_tokens']);
    final cacheWrite = asInt(usage['cache_creation_input_tokens']);
    final family = ModelFamily.resolve(model);
    final cwdValue = asNonEmptyString(row['cwd']);
    String? projectHint;
    if (cwdValue != null) {
      final parts = cwdValue
          .split(RegExp(r'[\\/]+'))
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) projectHint = parts.last;
    }

    return RawSession(
      providerIdentifier: id,
      profile: activeProfile?.name ?? 'Default',
      startedAt: timestamp,
      endedAt: timestamp,
      model: model,
      inputTokens: input,
      outputTokens: output,
      cacheReadTokens: cacheRead,
      cacheWriteTokens: cacheWrite,
      requestCount: 1,
      costUSD: family.pricing.totalCost(
        input: input,
        output: output,
        cacheRead: cacheRead,
        cacheWrite: cacheWrite,
      ),
      projectHint: projectHint,
    );
  }

  Map<String, dynamic>? _usagePayload(Map<String, dynamic> row) {
    final message = row['message'];
    if (message is Map<String, dynamic>) {
      final usage = message['usage'];
      if (usage is Map<String, dynamic> && _hasUsageFields(usage)) {
        return usage;
      }
    }
    if (_hasUsageFields(row)) return row;
    return null;
  }

  bool _hasUsageFields(Map<String, dynamic> map) =>
      map.containsKey('input_tokens') ||
      map.containsKey('output_tokens') ||
      map.containsKey('cache_read_input_tokens') ||
      map.containsKey('cache_creation_input_tokens');

  String? _modelName(Map<String, dynamic> row) {
    final message = row['message'];
    if (message is Map<String, dynamic>) {
      final name = asNonEmptyString(message['model']);
      if (name != null) return name;
    }
    return asNonEmptyString(row['model']);
  }

  Future<List<RawSession>> _fallbackHistorySessions({
    required DateTime since,
  }) async {
    final out = <RawSession>[];
    for (final file in _historyFiles) {
      if (!await file.exists()) continue;
      final rows = await JsonlReader.readObjects(file);
      for (final row in rows) {
        final timestamp = TimeHelpers.parseISODate(
              asNonEmptyString(row['timestamp']),
            ) ??
            TimeHelpers.parseISODate(asNonEmptyString(row['updated_at']));
        if (timestamp == null || timestamp.isBefore(since)) continue;
        out.add(RawSession(
          providerIdentifier: id,
          profile: activeProfile?.name ?? 'Default',
          startedAt: timestamp,
          endedAt: timestamp,
          model: _modelName(row) ?? 'claude',
          inputTokens: 0,
          outputTokens: 0,
          costUSD: 0,
          projectHint: asNonEmptyString(row['cwd']),
        ));
      }
    }
    return out;
  }
}
