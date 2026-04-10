import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/core/utils/traffic_formatter.dart';
import 'package:xboard_client/presentation/providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).fetchSubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cc = isDark ? AppColors.gray800 : Colors.white;
    final info = sub.info;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('订阅', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 24),

        if (info == null)
          Center(child: sub.isLoading
            ? CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
            : Text('暂无订阅信息', style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray500)))
        else ...[
          // Plan details
          _card('套餐详情', cc, isDark, child: Column(children: [
            _row('套餐名称', info.plan?.name ?? '无', isDark),
            _row('流量限额', TrafficFormatter.formatBytes(info.transferEnable), isDark),
            _row('速度限制', info.plan?.speedLimit != null ? '${info.plan!.speedLimit} Mbps' : '无限制', isDark),
            _row('设备限制', info.plan?.deviceLimit != null ? '${info.plan!.deviceLimit}' : '无限制', isDark),
            _row('到期时间', info.expiredDateStr, isDark),
            if (info.resetDay != null) _row('流量重置日', '每月 ${info.resetDay} 日', isDark),
          ])),
          const SizedBox(height: 16),

          // Subscribe URL
          _card('订阅链接', cc, isDark, child: Column(children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.gray700 : AppColors.gray100,
                borderRadius: BorderRadius.circular(12)),
              child: Text(info.subscribeUrl ?? '', style: TextStyle(fontSize: 13,
                color: isDark ? AppColors.gray400 : AppColors.gray500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: () {
                  if (info.subscribeUrl != null) {
                    Clipboard.setData(ClipboardData(text: info.subscribeUrl!));
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text(_copied ? '已复制！' : '复制', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              )),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _confirmReset(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                child: const Text('重置订阅链接', style: TextStyle(fontSize: 14)),
              ),
            ]),
          ])),
          const SizedBox(height: 16),

          // Traffic usage
          _card('流量使用', cc, isDark, child: Column(children: [
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth > 600 ? 4 : 2;
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                _trafficItem('上传', TrafficFormatter.formatBytes(info.upload), w, isDark),
                _trafficItem('下载', TrafficFormatter.formatBytes(info.download), w, isDark),
                _trafficItem('已用总量', TrafficFormatter.formatBytes(info.totalUsed), w, isDark),
                _trafficItem('剩余', TrafficFormatter.formatBytes(info.remaining), w, isDark, color: AppColors.success),
              ]);
            }),
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: info.usagePercent,
                backgroundColor: isDark ? AppColors.gray700 : AppColors.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                minHeight: 8)),
          ])),
        ],
      ]),
    );
  }

  Widget _card(String title, Color cc, bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cc, borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 16), child,
      ]),
    );
  }

  Widget _row(String label, String value, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.gray900)),
      ]));
  }

  Widget _trafficItem(String label, String value, double w, bool isDark, {Color? color}) {
    return SizedBox(width: w, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color ?? (isDark ? Colors.white : AppColors.gray900))),
    ]));
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) {
      final dk = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: dk ? AppColors.gray800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重置订阅链接', style: TextStyle(color: dk ? Colors.white : AppColors.gray900)),
        content: Text('确定要重置订阅链接吗？旧链接将失效。', style: TextStyle(color: dk ? AppColors.gray400 : AppColors.gray500, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: dk ? AppColors.gray400 : AppColors.gray500))),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); ref.read(subscriptionProvider.notifier).resetSecurity(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('确认重置', style: TextStyle(color: Colors.white))),
        ],
      );
    });
  }
}
