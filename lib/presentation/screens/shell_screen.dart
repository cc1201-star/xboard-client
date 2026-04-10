import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/providers/theme_provider.dart';
import 'package:xboard_client/presentation/widgets/custom_title_bar.dart';

bool get _isDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  bool _mobileMenuOpen = false;

  // Matching Layout.tsx navItems exactly (9 items, no 日志)
  static const _navItems = [
    _NavDef(icon: Icons.grid_view_rounded, label: '仪表盘', path: '/'),
    _NavDef(icon: Icons.bolt, label: '订阅', path: '/subscription'),
    _NavDef(icon: Icons.credit_card_outlined, label: '套餐', path: '/plans'),
    _NavDef(icon: Icons.description_outlined, label: '订单', path: '/orders'),
    _NavDef(icon: Icons.download_outlined, label: '流量包', path: '/traffic-packages'),
    _NavDef(icon: Icons.account_balance_wallet_outlined, label: '充值', path: '/recharge'),
    _NavDef(icon: Icons.chat_bubble_outline, label: '工单', path: '/tickets'),
    _NavDef(icon: Icons.notifications_outlined, label: '公告', path: '/notices'),
    _NavDef(icon: Icons.settings_outlined, label: '设置', path: '/settings'),
  ];

  bool _colorLoaded = false;
  Color get _sidebarColor => ref.watch(themeColorProvider);

  @override
  Widget build(BuildContext context) {
    // 进入主页后重新加载颜色（登录页只写了 SharedPreferences，没更新 provider）
    if (!_colorLoaded) {
      _colorLoaded = true;
      Future.microtask(() => ref.read(themeColorProvider.notifier).reload());
    }
    final location = GoRouterState.of(context).matchedLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1024; // lg breakpoint

    return Scaffold(
      body: Column(
        children: [
          if (_isDesktop) const CustomTitleBar(),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    // Desktop Sidebar - hidden on mobile
                    if (!isMobile) _buildSidebar(location),
                    // Main Content
                    Expanded(
                      child: Column(
                        children: [
                          // Mobile header
                          if (isMobile) _buildMobileHeader(isDark),
                          Expanded(
                            child: Container(
                              color: isDark ? AppColors.gray900 : AppColors.gray50,
                              child: widget.child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Mobile sidebar overlay
                if (isMobile && _mobileMenuOpen) ...[
                  GestureDetector(
                    onTap: () => setState(() => _mobileMenuOpen = false),
                    child: Container(color: Colors.black.withValues(alpha: 0.5)),
                  ),
                  Positioned(
                    left: 0, top: 0, bottom: 0, width: 256,
                    child: _buildSidebar(location),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(String location) {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: _sidebarColor,
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _sidebarColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Xboard', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _navItems.map((item) => _NavTile(
                icon: item.icon,
                label: item.label,
                selected: location == item.path,
                onTap: () {
                  context.go(item.path);
                  setState(() => _mobileMenuOpen = false);
                },
              )).toList(),
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: _NavTile(
              icon: Icons.logout,
              label: '退出登录',
              selected: false,
              onTap: () => ref.read(authStateProvider.notifier).logout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
          ? AppColors.gray900.withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(
          color: isDark ? AppColors.gray800 : AppColors.gray200)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _mobileMenuOpen = true),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.menu, size: 24,
                color: isDark ? AppColors.gray400 : AppColors.gray500),
            ),
          ),
          const SizedBox(width: 16),
          Text('Xboard', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900)),
        ],
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String label;
  final String path;
  const _NavDef({required this.icon, required this.label, required this.path});
}

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: widget.selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : _hover ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(widget.icon, size: 20, color: Colors.white),
              const SizedBox(width: 16),
              Text(widget.label, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}
