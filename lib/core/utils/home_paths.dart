import 'dart:io';

import 'package:path/path.dart' as p;

/// Cross-platform home directory helpers.
///
/// macOS / Linux: `$HOME`
/// Windows: `%USERPROFILE%`
/// iOS: uses the app's documents directory via [path_provider] when
/// callers need filesystem access (providers skip file scanning on iOS).
class HomePaths {
  HomePaths._();

  static String? get home {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'];
    }
    return Platform.environment['HOME'];
  }

  static Directory? directory(String subpath) {
    final base = home;
    if (base == null) return null;
    return Directory(p.join(base, subpath));
  }

  static File? file(String subpath) {
    final base = home;
    if (base == null) return null;
    return File(p.join(base, subpath));
  }

  static String? env(String name) {
    final raw = Platform.environment[name]?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static bool envFlag(String name) {
    final v = env(name)?.toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }

  /// On iOS/Android filesystem access to user home is sandboxed — providers
  /// should skip local file scanning on these platforms.
  static bool get supportsLocalFileScanning =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;
}
