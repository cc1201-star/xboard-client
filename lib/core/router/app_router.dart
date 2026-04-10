import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/screens/login/login_screen.dart';
import 'package:xboard_client/presentation/screens/home/home_screen.dart';
import 'package:xboard_client/presentation/screens/subscription/subscription_screen.dart';
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
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionScreen()),
          GoRoute(path: '/plans', builder: (context, state) => const PlansScreen()),
          GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
          GoRoute(path: '/traffic-packages', builder: (context, state) => const TrafficPackagesScreen()),
          GoRoute(path: '/recharge', builder: (context, state) => const RechargeScreen()),
          GoRoute(path: '/tickets', builder: (context, state) => const TicketsScreen()),
          GoRoute(path: '/notices', builder: (context, state) => const NoticesScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/logs', builder: (context, state) => const LogViewerScreen()),
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
