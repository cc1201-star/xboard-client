import 'package:flutter/material.dart';

/// Show a toast-style message at the top of the **content area** (avoids
/// overlapping the sidebar). [context] should belong to a widget inside the
/// content region so its RenderBox gives the correct bounds.
void showTopToast(BuildContext context, String message, {bool isError = false}) {
  final overlay = Overlay.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final box = context.findRenderObject() as RenderBox?;

  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) => _TopToast(
    message: message,
    isError: isError,
    isDark: isDark,
    contentBox: box,
    onDismiss: () => entry.remove(),
  ));

  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isDark;
  final RenderBox? contentBox;
  final VoidCallback onDismiss;

  const _TopToast({required this.message, required this.isError, required this.isDark, this.contentBox, required this.onDismiss});

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
    // Find the content area RenderBox so the toast stays inside it
    // (doesn't overlap the sidebar). The context passed to showTopToast
    // belongs to a widget inside the content area, so its RenderBox gives
    // us the correct left offset and width.
    final box = widget.contentBox;
    final double left = box != null ? box.localToGlobal(Offset.zero).dx + 24 : 24;
    final double right = box != null
        ? MediaQuery.of(context).size.width - (box.localToGlobal(Offset.zero).dx + box.size.width) + 24
        : 24;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: left, right: right,
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
