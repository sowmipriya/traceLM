import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/burn_rate_calculator.dart';
import '../services/settings_service.dart';
import '../utils/time_helpers.dart';
import 'usage_provider.dart';

/// Live usage from the OpenAI Usage API. Opt-in: user must paste a key into
/// Settings → Sources. The key is stored via [SettingsService.setSecret] which
/// is plaintext on disk — swap in `flutter_secure_storage` for production.
class OpenAiApiProvider implements UsageProvider {
  OpenAiApiProvider(this.settings, {http.Client? client})
      : _client = client ?? http.Client();

  static const String id = 'openai-api';
  static const String _secretKey = 'openai.apiKey';

  final SettingsService settings;
  final http.Client _client;
  final BurnRateCalculator _calc = BurnRateCalculator();

  @override
  String get identifier => id;
  @override
  String get displayName => 'OpenAI API';
  @override
  ProviderCategory get category => ProviderCategory.usageBased;

  @override
  bool get isEnabled =>
      settings.providerEnabled(id, defaultValue: false) &&
      (settings.secret(_secretKey)?.isNotEmpty ?? false);
  @override
  set isEnabled(bool value) => settings.setProviderEnabled(id, value);

  @override
  List<ProviderProfile> get profiles =>
      const [ProviderProfile(name: 'Default')];
  @override
  ProviderProfile? activeProfile = const ProviderProfile(name: 'Default');

  @override
  Future<List<RawSession>> sessions({required DateTime since}) async => const [];

  @override
  Future<bool> isAvailable() async =>
      (settings.secret(_secretKey)?.isNotEmpty ?? false);

  @override
  Future<ProviderResult> probe() async {
    final apiKey = settings.secret(_secretKey);
    if (apiKey == null || apiKey.isEmpty) {
      return ProviderResult.unavailable(
        identifier: id,
        displayName: displayName,
        category: category,
        warning: 'No API key configured. Add one in Settings → Sources.',
      );
    }

    final sessions = await _fetchUsage(apiKey: apiKey);
    return _calc.buildHeuristicResult(
      identifier: id,
      displayName: displayName,
      category: category,
      profile: activeProfile?.name ?? 'Default',
      sessions: sessions,
      source: DataSource.api,
    );
  }

  Future<List<RawSession>> _fetchUsage({required String apiKey}) async {
    // OpenAI's usage endpoint is date-scoped; request the last 30 days.
    final out = <RawSession>[];
    final now = DateTime.now();
    for (var daysAgo = 0; daysAgo < 30; daysAgo++) {
      final date = TimeHelpers.dayFormatter.format(
          DateTime(now.year, now.month, now.day - daysAgo));
      final uri = Uri.parse('https://api.openai.com/v1/usage?date=$date');
      try {
        final res = await _client.get(uri, headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final body = json.decode(res.body);
        if (body is! Map<String, dynamic>) continue;
        final rows = body['data'];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map<String, dynamic>) continue;
          final ts = row['aggregation_timestamp'];
          if (ts is! int) continue;
          final model = row['snapshot_id'] ?? row['model'] ?? 'gpt';
          final input = (row['n_context_tokens_total'] as num?)?.toInt() ?? 0;
          final output = (row['n_generated_tokens_total'] as num?)?.toInt() ?? 0;
          final requests = (row['n_requests'] as num?)?.toInt() ?? 1;
          final family = ModelFamily.resolve(model.toString());
          out.add(RawSession(
            providerIdentifier: id,
            profile: activeProfile?.name ?? 'Default',
            startedAt: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
            endedAt: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
            model: model.toString(),
            inputTokens: input,
            outputTokens: output,
            requestCount: requests,
            costUSD: family.pricing.totalCost(input: input, output: output),
          ));
        }
      } catch (_) {
        // Rate limits / flaky network: keep going.
        continue;
      }
    }
    out.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return out;
  }
}
