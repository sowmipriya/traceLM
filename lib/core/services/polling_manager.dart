import 'dart:async';

import '../models/models.dart';
import 'notification_service.dart';
import 'service_status_monitor.dart';
import 'statusline_exporter.dart';
import 'usage_aggregator.dart';

/// Polls the aggregator on an adaptive cadence:
///   * `foreground` when the app window is focused (user is actively looking)
///   * `background` when minimized / user is AFK / laptop on battery
///
/// Also forwards each snapshot to the notification service and the statusline
/// exporter so they stay in lockstep with the dashboard.
class PollingManager {
  PollingManager({
    required this.aggregator,
    required this.serviceStatusMonitor,
    required this.exporter,
    required this.notifications,
    this.foreground = const Duration(seconds: 30),
    this.background = const Duration(minutes: 5),
    this.batterySaver = const Duration(minutes: 15),
  });

  final UsageAggregator aggregator;
  final ServiceStatusMonitor serviceStatusMonitor;
  final StatuslineExporter exporter;
  final TraceLMNotificationService notifications;
  final Duration foreground;
  final Duration background;
  final Duration batterySaver;

  Timer? _timer;
  Duration _current = const Duration(minutes: 5);

  void start() {
    if (_timer != null) return;
    _current = background;
    _schedule();
    // Kick an immediate refresh so the UI has data on first paint.
    unawaited(_refresh(force: false));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void onAppFocus() {
    _current = foreground;
    _reschedule();
  }

  void onAppBlur() {
    _current = background;
    _reschedule();
  }

  void onPowerChange({required bool unplugged}) {
    _current = unplugged ? batterySaver : background;
    _reschedule();
  }

  Future<void> forceRefresh() => _refresh(force: true);

  void _schedule() {
    _timer = Timer.periodic(_current, (_) => _refresh(force: false));
  }

  void _reschedule() {
    _timer?.cancel();
    _schedule();
  }

  Future<void> _refresh({required bool force}) async {
    await Future.wait<void>([
      aggregator.refresh(force: force),
      serviceStatusMonitor.refresh(force: force),
    ]);
    final snapshot = aggregator.snapshot;
    if (snapshot == null) return;
    await exporter.export(snapshot);
    await notifications.handleSnapshot(snapshot);
    _warnOnPoorUsage(snapshot);
  }

  /// Bucket #2 of the user brief: "poor usage". Burn rate near zero for an
  /// active session window likely means the user stopped working mid-session
  /// but the tool is still holding context — surface a gentle nudge.
  Future<void> _warnOnPoorUsage(UsageSnapshot snapshot) async {
    for (final p in snapshot.providers) {
      final burn = p.burnRate;
      final primary = p.primaryWindow;
      if (burn == null || primary == null) continue;
      if (burn.tokensPerMinute < 5 && primary.percentage > 0 && primary.percentage < 40) {
        await notifications.notifyInformational(
          title: 'Low activity on ${p.displayName}',
          body:
              'Burn rate is ${burn.tokensPerMinute.toStringAsFixed(1)} tok/min. Consider closing the session to reclaim quota.',
        );
      }
    }
  }
}
