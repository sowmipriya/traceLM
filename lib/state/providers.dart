import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/provider_registry.dart';
import '../core/services/notification_service.dart';
import '../core/services/polling_manager.dart';
import '../core/services/service_status_monitor.dart';
import '../core/services/settings_service.dart';
import '../core/services/statusline_exporter.dart';
import '../core/services/usage_aggregator.dart';

/// Root dependency wiring. Every screen in [lib/ui] only talks to the
/// aggregator and settings service through these providers — no global
/// singletons, so tests can override any layer in isolation.

final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError('override in bootstrap');
});

final providerRegistryProvider = ChangeNotifierProvider<ProviderRegistry>((ref) {
  return ProviderRegistry(ref.watch(settingsServiceProvider));
});

final usageAggregatorProvider = ChangeNotifierProvider<UsageAggregator>((ref) {
  return UsageAggregator(ref.watch(providerRegistryProvider));
});

final serviceStatusMonitorProvider =
    ChangeNotifierProvider<ServiceStatusMonitor>((ref) {
  return ServiceStatusMonitor();
});

final notificationServiceProvider =
    Provider<TraceLMNotificationService>((ref) {
  final service = TraceLMNotificationService(
    settings: ref.watch(settingsServiceProvider),
  );
  // Permission prompt happens the first time we call initialize().
  service.initialize();
  return service;
});

final statuslineExporterProvider = Provider<StatuslineExporter>((ref) {
  return StatuslineExporter(ref.watch(settingsServiceProvider));
});

final pollingManagerProvider = Provider<PollingManager>((ref) {
  final polling = PollingManager(
    aggregator: ref.watch(usageAggregatorProvider),
    serviceStatusMonitor: ref.watch(serviceStatusMonitorProvider),
    exporter: ref.watch(statuslineExporterProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(polling.stop);
  return polling;
});
