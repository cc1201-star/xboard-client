import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initPlatform() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1000, 680),
      minimumSize: Size(600, 480),
      center: true,
      title: 'Xboard',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.white,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
