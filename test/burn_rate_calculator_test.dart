import 'package:flutter_test/flutter_test.dart';
import 'package:tracelm/core/models/provider_result.dart';
import 'package:tracelm/core/models/raw_session.dart';
import 'package:tracelm/core/services/burn_rate_calculator.dart';

void main() {
  RawSession makeSession(DateTime at,
          {int input = 1000, int output = 500}) =>
      RawSession(
        providerIdentifier: 'test',
        profile: 'Default',
        startedAt: at,
        endedAt: at,
        model: 'claude-sonnet',
        inputTokens: input,
        outputTokens: output,
        costUSD: 0.01,
      );

  test('todayUsage only counts sessions from today', () {
    final calc = BurnRateCalculator();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final usage = calc.todayUsage([
      makeSession(yesterday),
      makeSession(now),
      makeSession(now.subtract(const Duration(hours: 1))),
    ]);
    expect(usage.requests, 2);
    expect(usage.tokens, 2 * 1500);
  });

  test('burnRate returns null when there is no recent activity', () {
    final calc = BurnRateCalculator();
    final rate = calc.burnRate(
      sessions: [
        makeSession(DateTime.now().subtract(const Duration(hours: 3))),
      ],
    );
    expect(rate, isNull);
  });

  test('buildHeuristicResult computes windows and heatmap', () {
    final calc = BurnRateCalculator();
    final now = DateTime.now();
    final sessions = List.generate(
      5,
      (i) => makeSession(now.subtract(Duration(minutes: i * 20))),
    );
    final result = calc.buildHeuristicResult(
      identifier: 'test',
      displayName: 'Test',
      category: ProviderCategory.api,
      profile: 'Default',
      sessions: sessions,
      source: DataSource.local,
    );
    expect(result.windows, isNotEmpty);
    expect(result.dailyHeatmap.length, 90);
    expect(result.today.tokens, greaterThan(0));
  });
}
