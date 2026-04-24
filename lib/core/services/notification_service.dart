import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';
import '../utils/time_helpers.dart';
import 'settings_service.dart';

/// Drives the actual "you're exceeding / at X%" alerts that the user signed
/// up for. Dedupes each (provider, window, threshold, resetAt) tuple so a
/// single threshold crossing doesn't spam the user across poll cycles.
class TraceLMNotificationService {
  TraceLMNotificationService({
    required this.settings,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final SettingsService settings;
  final FlutterLocalNotificationsPlugin _plugin;
  final Set<String> _deliveredKeys = <String>{};

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open');

    await _plugin.initialize(const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
    ));

    // Darwin (macOS/iOS) explicitly requires a permission prompt.
    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Inspects every window on every provider and fires a notification the
  /// first time each enabled threshold is crossed within a reset window.
  Future<void> handleSnapshot(UsageSnapshot snapshot) async {
    if (_isQuietHours()) return;

    for (final provider in snapshot.providers) {
      for (final window in provider.windows) {
        if (window.kind is! FiveHourWindow &&
            window.kind is! WeeklyWindow) {
          continue;
        }
        for (final threshold in settings.enabledThresholds) {
          if (window.percentage < threshold) continue;
          final resetKey = window.resetAt == null
              ? 'none'
              : TimeHelpers.iso8601(window.resetAt!);
          final key =
              '${provider.identifier}:${window.kind.reportingKey}:$threshold:$resetKey';
          if (_deliveredKeys.contains(key)) continue;
          _deliveredKeys.add(key);

          await _send(
            title: _title(threshold, window.kind),
            body:
                '${provider.displayName} is at ${window.percentage.round()}%.',
          );
        }
      }
    }
  }

  /// Informational notification for "poor usage" or system events.
  Future<void> notifyInformational({
    required String title,
    required String body,
  }) async {
    if (_isQuietHours()) return;
    await _send(title: title, body: body);
  }

  String _title(int threshold, WindowKind kind) {
    final label = kind is WeeklyWindow ? 'Weekly' : 'Session';
    if (threshold >= 100) return '$label limit reached';
    return '$label at $threshold%';
  }

  bool _isQuietHours() {
    if (!settings.quietHoursEnabled) return false;
    final start = settings.quietStartHour;
    final end = settings.quietEndHour;
    final hour = DateTime.now().hour;
    if (start <= end) return hour >= start && hour < end;
    return hour >= start || hour < end;
  }

  Future<void> _send({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'tracelm.quota',
      'Quota alerts',
      channelDescription: 'Notifications when an LLM quota threshold is crossed.',
      importance: Importance.high,
      priority: Priority.high,
    );
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: settings.notificationSound,
    );
    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
        linux: linuxDetails,
      ),
    );
  }
}
