import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/core/router/app_router.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/providers/theme_provider.dart';
import 'package:xboard_client/main_desktop.dart' if (dart.library.html) 'package:xboard_client/main_web.dart' as platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await platform.initPlatform();
  runApp(const ProviderScope(child: XboardApp()));
}

class XboardApp extends ConsumerStatefulWidget {
  const XboardApp({super.key});

  @override
  ConsumerState<XboardApp> createState() => _XboardAppState();
}

class _XboardAppState extends ConsumerState<XboardApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) windowManager.addListener(this);
    ref.read(authStateProvider.notifier).checkAuth();
  }

  @override
  void dispose() {
    if (!kIsWeb) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    // 点击窗口 X 按钮时隐藏到托盘，不退出
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final primaryColor = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: 'Xboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeWith(primaryColor),
      darkTheme: AppTheme.darkThemeWith(primaryColor),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
