import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xboard_client/presentation/providers/theme_provider.dart';

class CustomTitleBar extends ConsumerWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();

    final sidebarColor = ref.watch(themeColorProvider);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 32,
        color: sidebarColor,
        child: Row(
          children: [
            const SizedBox(width: 76),
            const Spacer(),
            _TitleBarButton(
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
              hoverColor: Colors.white.withValues(alpha: 0.1),
            ),
            _TitleBarButton(
              icon: Icons.crop_square,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              hoverColor: Colors.white.withValues(alpha: 0.1),
            ),
            _TitleBarButton(
              icon: Icons.close,
              onTap: () => windowManager.hide(),
              hoverColor: const Color(0xFFE81123),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color hoverColor;

  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    required this.hoverColor,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovering ? widget.hoverColor : Colors.transparent,
          child: Icon(
            widget.icon,
            color: Colors.white70,
            size: 14,
          ),
        ),
      ),
    );
  }
}
