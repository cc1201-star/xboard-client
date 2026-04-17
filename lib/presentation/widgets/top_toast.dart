import 'package:flutter/material.dart';

/// Sidebar width used in ShellScreen — keep in sync.
const _sidebarWidth = 256.0;
const _mobileBreakpoint = 1024.0;

/// Show a toast-style message aligned with the content area (right of sidebar).
/// Always calculates position from screen dimensions so the toast spans the
/// full content width regardless of which widget triggered it.
void showTopToast(BuildContext context, String message, {bool isError = false}) {
  final overlay = Overlay.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) => _TopToast(
    message: message,
    isError: isError,
    isDark: isDark,
    onDismiss: () => entry.remove(),
  ));

  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isDark;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.isError,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final screenWidth = MediaQuery.of(context).size.width;
    final hasSidebar = screenWidth >= _mobileBreakpoint;

    // Title bar height on desktop.
    const titleBarH = 32.0;
    final topOffset = hasSidebar ? titleBarH + 12 : MediaQuery.of(context).padding.top + 12;

    final double left = hasSidebar ? _sidebarWidth : 16;
    final double right = hasSidebar ? 0 : 16;

    return Positioned(
      top: topOffset,
      left: left,
      right: right,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Icon(widget.isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
            ]),
          ),
        ),
      ),
    );
  }
}
