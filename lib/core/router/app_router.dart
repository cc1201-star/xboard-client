import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/screens/login/login_screen.dart';
import 'package:xboard_client/presentation/screens/home/home_screen.dart';
import 'package:xboard_client/presentation/screens/subscription/subscription_screen.dart';
import 'package:xboard_client/presentation/screens/nodes/nodes_screen.dart';
import 'package:xboard_client/presentation/screens/plans/plans_screen.dart';
import 'package:xboard_client/presentation/screens/orders/orders_screen.dart';
import 'package:xboard_client/presentation/screens/traffic_packages/traffic_packages_screen.dart';
import 'package:xboard_client/presentation/screens/recharge/recharge_screen.dart';
import 'package:xboard_client/presentation/screens/tickets/tickets_screen.dart';
import 'package:xboard_client/presentation/screens/notices/notices_screen.dart';
import 'package:xboard_client/presentation/screens/settings/settings_screen.dart';
import 'package:xboard_client/presentation/screens/logs/log_viewer_screen.dart';
import 'package:xboard_client/presentation/screens/shell_screen.dart';

/// A ChangeNotifier that bridges Riverpod → GoRouter refreshListenable.
/// GoRouter only re-evaluates redirect when this fires, without recreating itself.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      if (!authState.isInitialized) {
        if (state.matchedLocation != '/splash') return '/splash';
        return null;
      }

      final isAuth = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return isAuth ? '/' : '/login';
      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (c, s) => _fadeUp(const HomeScreen())),
          GoRoute(path: '/subscription', pageBuilder: (c, s) => _fadeUp(const SubscriptionScreen())),
          GoRoute(path: '/nodes', pageBuilder: (c, s) => _fadeUp(const NodesScreen())),
          GoRoute(path: '/plans', pageBuilder: (c, s) => _fadeUp(const PlansScreen())),
          GoRoute(path: '/orders', pageBuilder: (c, s) => _fadeUp(const OrdersScreen())),
          GoRoute(path: '/traffic-packages', pageBuilder: (c, s) => _fadeUp(const TrafficPackagesScreen())),
          GoRoute(path: '/recharge', pageBuilder: (c, s) => _fadeUp(const RechargeScreen())),
          GoRoute(path: '/tickets', pageBuilder: (c, s) => _fadeUp(const TicketsScreen())),
          GoRoute(path: '/notices', pageBuilder: (c, s) => _fadeUp(const NoticesScreen())),
          GoRoute(path: '/settings', pageBuilder: (c, s) => _fadeUp(const SettingsScreen())),
          GoRoute(path: '/logs', pageBuilder: (c, s) => _fadeUp(const LogViewerScreen())),
        ],
      ),
    ],
  );
});

/// Shell 内菜单切换的过渡:220ms 淡入 + 8px 上滑,曲线 easeOutCubic
/// 与 C.API 网页的风格保持一致,体感"丝滑"
CustomTransitionPage<void> _fadeUp(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, _, c) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(curve),
          child: c,
        ),
      );
    },
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(width: 32, height: 32,
          child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
