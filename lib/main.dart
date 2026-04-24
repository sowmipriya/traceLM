import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/settings_service.dart';
import 'state/providers.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window chrome: size + min size, so the dashboard has breathing
  // room on Windows/Linux/macOS.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1000, 720),
        minimumSize: Size(640, 520),
        center: true,
        title: 'TraceLM',
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final settings = await SettingsService.create();

  runApp(ProviderScope(
    overrides: [settingsServiceProvider.overrideWithValue(settings)],
    child: const TraceLMApp(),
  ));
}
