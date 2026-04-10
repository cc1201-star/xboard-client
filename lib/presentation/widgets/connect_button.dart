import 'package:flutter/material.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/vpn_state_provider.dart';

class ConnectButton extends StatefulWidget {
  final VpnStatus status;
  final String? currentNode;
  final VoidCallback onTap;

  const ConnectButton({
    super.key,
    required this.status,
    this.currentNode,
    required this.onTap,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didUpdateWidget(ConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == VpnStatus.connecting || widget.status == VpnStatus.disconnecting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == VpnStatus.connected;
    final isTransitioning =
        widget.status == VpnStatus.connecting || widget.status == VpnStatus.disconnecting;

    final color = isConnected
        ? AppColors.success
        : isTransitioning
            ? AppColors.warning
            : AppColors.gray300;

    return Column(
      children: [
        GestureDetector(
          onTap: isTransitioning ? null : widget.onTap,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = isTransitioning ? 1.0 + _pulseController.value * 0.06 : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color, width: 3),
                    boxShadow: isConnected
                        ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 4)]
                        : null,
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    color: color,
                    size: 48,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isConnected
                ? AppColors.successBg
                : isTransitioning
                    ? AppColors.warningBg
                    : AppColors.gray100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            switch (widget.status) {
              VpnStatus.connected => '已连接',
              VpnStatus.connecting => '连接中...',
              VpnStatus.disconnecting => '断开中...',
              VpnStatus.disconnected => '未连接',
            },
            style: TextStyle(
              color: isConnected
                  ? AppColors.success
                  : isTransitioning
                      ? AppColors.warning
                      : AppColors.gray500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (widget.currentNode != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.currentNode!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
