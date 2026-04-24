import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight key/value store backed by SharedPreferences.
/// Keeps all tunable thresholds and feature flags in one place.
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> create() async =>
      SettingsService(await SharedPreferences.getInstance());

  // --- notification thresholds ----------------------------------------------
  static const _defaultThresholds = [75, 90, 95, 100];
  static const _defaultEnabledThresholds = {75, 90, 100};

  List<int> get enabledThresholds => _defaultThresholds
      .where((t) =>
          _prefs.getBool('notify.threshold.$t') ??
          _defaultEnabledThresholds.contains(t))
      .toList();

  bool isThresholdEnabled(int threshold) =>
      _prefs.getBool('notify.threshold.$threshold') ??
      _defaultEnabledThresholds.contains(threshold);

  Future<void> setThreshold(int threshold, bool enabled) =>
      _prefs.setBool('notify.threshold.$threshold', enabled);

  // --- quiet hours ----------------------------------------------------------
  bool get quietHoursEnabled => _prefs.getBool('notify.quiet.enabled') ?? false;
  Future<void> setQuietHoursEnabled(bool v) =>
      _prefs.setBool('notify.quiet.enabled', v);

  int get quietStartHour => _prefs.getInt('notify.quiet.startHour') ?? 22;
  Future<void> setQuietStartHour(int v) =>
      _prefs.setInt('notify.quiet.startHour', v);

  int get quietEndHour => _prefs.getInt('notify.quiet.endHour') ?? 8;
  Future<void> setQuietEndHour(int v) =>
      _prefs.setInt('notify.quiet.endHour', v);

  bool get notificationSound => _prefs.getBool('notify.sound') ?? true;
  Future<void> setNotificationSound(bool v) =>
      _prefs.setBool('notify.sound', v);

  // --- providers ------------------------------------------------------------
  bool providerEnabled(String id, {bool defaultValue = true}) =>
      _prefs.getBool('provider.$id.enabled') ?? defaultValue;

  Future<void> setProviderEnabled(String id, bool enabled) =>
      _prefs.setBool('provider.$id.enabled', enabled);

  // --- advanced -------------------------------------------------------------
  bool get statuslineExportEnabled =>
      _prefs.getBool('advanced.statusline.enabled') ?? true;
  Future<void> setStatuslineExportEnabled(bool v) =>
      _prefs.setBool('advanced.statusline.enabled', v);

  bool get launchAtLoginEnabled =>
      _prefs.getBool('advanced.launchAtLogin') ?? false;
  Future<void> setLaunchAtLoginEnabled(bool v) =>
      _prefs.setBool('advanced.launchAtLogin', v);

  // Freeform secret storage (API keys etc.). NOTE: SharedPreferences is NOT a
  // secure store — on desktop these values are plaintext on disk. Users who
  // need secrets should install a keychain-backed plugin (flutter_secure_storage).
  String? secret(String key) => _prefs.getString('secret.$key');
  Future<void> setSecret(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove('secret.$key');
    } else {
      await _prefs.setString('secret.$key', value);
    }
  }
}
