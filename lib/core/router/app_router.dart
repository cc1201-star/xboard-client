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
          GoRoute(path: '/', pageBuilder: (c, s) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/subscription', pageBuilder: (c, s) => const NoTransitionPage(child: SubscriptionScreen())),
          GoRoute(path: '/nodes', pageBuilder: (c, s) => const NoTransitionPage(child: NodesScreen())),
          GoRoute(path: '/plans', pageBuilder: (c, s) => const NoTransitionPage(child: PlansScreen())),
          GoRoute(path: '/orders', pageBuilder: (c, s) => const NoTransitionPage(child: OrdersScreen())),
          GoRoute(path: '/traffic-packages', pageBuilder: (c, s) => const NoTransitionPage(child: TrafficPackagesScreen())),
          GoRoute(path: '/recharge', pageBuilder: (c, s) => const NoTransitionPage(child: RechargeScreen())),
          GoRoute(path: '/tickets', pageBuilder: (c, s) => const NoTransitionPage(child: TicketsScreen())),
          GoRoute(path: '/notices', pageBuilder: (c, s) => const NoTransitionPage(child: NoticesScreen())),
          GoRoute(path: '/settings', pageBuilder: (c, s) => const NoTransitionPage(child: SettingsScreen())),
          GoRoute(path: '/logs', pageBuilder: (c, s) => const NoTransitionPage(child: LogViewerScreen())),
        ],
      ),
    ],
  );
});

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
