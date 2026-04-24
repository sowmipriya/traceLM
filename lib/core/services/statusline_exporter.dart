import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../utils/home_paths.dart';
import '../utils/time_helpers.dart';
import 'settings_service.dart';

/// Mirrors CirrondlyDesk/Core/Services/StatusLineExporter.swift. Writes
/// `~/.tracelm/usage.json` atomically so shell prompts, tmux, and the
/// Claude Code `statusLine` script can read a stable file.
class StatuslineExporter {
  StatuslineExporter(this.settings);
  final SettingsService settings;

  Future<void> export(UsageSnapshot snapshot) async {
    if (!settings.statuslineExportEnabled) return;
    if (!HomePaths.supportsLocalFileScanning) return;

    final home = HomePaths.home;
    if (home == null) return;

    final directory = Directory(p.join(home, '.tracelm'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'usage.json'));
    final tempFile = File(p.join(directory.path, 'usage.json.tmp'));

    final payload = _makePayload(snapshot);
    final encoded =
        const JsonEncoder.withIndent('  ').convert(payload);

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Map<String, Object?> _makePayload(UsageSnapshot snapshot) {
    final providers = <String, Object?>{};
    for (final provider in snapshot.providers) {
      final payload = <String, Object?>{
        'today_cost_usd': provider.today.costUSD,
      };
      final burn = provider.burnRate;
      if (burn != null) {
        payload['burn_rate_usd_hr'] = burn.costPerHour;
      }
      for (final window in provider.windows) {
        payload[window.kind.reportingKey] = {
          'utilization': window.percentage.round(),
          'resets_at': window.resetAt == null
              ? null
              : TimeHelpers.iso8601(window.resetAt!),
        };
      }
      providers[provider.identifier] = payload;
    }

    return {
      'last_updated': TimeHelpers.iso8601(snapshot.generatedAt),
      'providers': providers,
      'summary': {
        'worst_percentage': snapshot.summary.worstPercentage.round(),
        'worst_provider': snapshot.summary.worstProvider,
        'worst_window': snapshot.summary.worstWindow,
        'total_cost_today_usd': snapshot.summary.totalCostTodayUSD,
        'total_tokens_today': snapshot.summary.totalTokensToday,
      },
    };
  }
}
