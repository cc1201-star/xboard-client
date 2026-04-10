import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
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
      // 拦截窗口关闭，改为隐藏到托盘
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    // 初始化系统托盘
    await _initTray();
  }
}

Future<void> _initTray() async {
  await trayManager.setIcon(
    Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
  );
  await trayManager.setToolTip('Xboard');
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'show', label: '显示窗口'),
    MenuItem.separator(),
    MenuItem(key: 'exit', label: '退出'),
  ]));
  trayManager.addListener(_TrayListener());
}

class _TrayListener extends TrayListener {
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'exit':
        windowManager.setPreventClose(false);
        windowManager.close();
        break;
    }
  }
}
