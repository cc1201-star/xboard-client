import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/core/utils/traffic_formatter.dart';
import 'package:xboard_client/presentation/providers/package_stats_provider.dart';
import 'package:xboard_client/presentation/providers/subscription_provider.dart';
import 'package:xboard_client/presentation/providers/user_provider.dart';
import 'package:xboard_client/presentation/providers/vpn_state_provider.dart';
import 'package:xboard_client/presentation/widgets/top_toast.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).fetchSubscription();
      ref.read(userProvider.notifier).fetchAll();
      ref.read(packageStatsProvider.notifier).refresh();
    });
  }

  String _formatDate(int? ts) {
    if (ts == null || ts == 0) return '永不过期';
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final userState = ref.watch(userProvider);
    final vpn = ref.watch(vpnStateProvider);
    final pkgStats = ref.watch(packageStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pc = Theme.of(context).colorScheme.primary;
    final info = sub.info;
    final user = userState.user;

    if (sub.isLoading && info == null) {
      return Center(child: SizedBox(width: 32, height: 32,
        child: CircularProgressIndicator(strokeWidth: 2, color: pc)));
    }

    final totalUsed = (info?.upload ?? 0) + (info?.download ?? 0);
    final rawTotal = info?.transferEnable ?? user?.transferEnable ?? 0;
    final pkgTrafficTotal = pkgStats.totalBytes;
    final pkgUsedTotal = pkgStats.usedBytes;
    final totalTraffic = (rawTotal - pkgTrafficTotal).clamp(0, rawTotal).toInt();
    final usedTraffic = (totalUsed - pkgUsedTotal).clamp(0, totalTraffic).toInt();
    final pct = totalTraffic > 0 ? (usedTraffic / totalTraffic * 100).clamp(0, 100).toDouble() : 0.0;
    final pkgTotal = pkgTrafficTotal;
    final pkgUsed = pkgUsedTotal;
    final pkgPct = pkgTotal > 0 ? (pkgUsed / pkgTotal * 100).clamp(0, 100).toDouble() : 0.0;
    final pkgCount = pkgStats.packageCount;
    final balance = user?.balance ?? 0;
    final stat = userState.stat;
    final expiredAt = user?.expiredAt ?? info?.expiredAt ?? 0;
    final isValid = expiredAt == 0 || (expiredAt * 1000 > DateTime.now().millisecondsSinceEpoch);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('欢迎回来，${user?.username ?? user?.email ?? '用户'}',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 24),

        _buildStatsRow(isDark, balance, stat),
        const SizedBox(height: 24),

        LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth > 700;
          if (wide) {
            return Column(children: [
              // Row 1: 套餐流量 + 流量包
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _buildTrafficCircle('套餐流量', pct, usedTraffic, totalTraffic, isDark, pc)),
                const SizedBox(width: 24),
                Expanded(child: _buildPackageCircle(pkgPct, pkgUsed, pkgTotal, isDark, pc)),
              ])),
              // 流量消耗优先级
              if (pkgCount > 0) ...[
                const SizedBox(height: 24),
                _buildTrafficPriority(isDark, pc),
              ],
              const SizedBox(height: 24),
              // Row 2: 订阅 + VPN (等高)
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _buildSubscriptionCard(info, isDark, expiredAt, isValid, pc)),
                const SizedBox(width: 24),
                Expanded(child: _buildVpnCard(vpn, isDark, pc)),
              ])),
            ]);
          }
          // Mobile: stacked
          return Column(children: [
            _buildTrafficCircle('套餐流量', pct, usedTraffic, totalTraffic, isDark, pc),
            const SizedBox(height: 24),
            _buildPackageCircle(pkgPct, pkgUsed, pkgTotal, isDark, pc),
            if (pkgCount > 0) ...[
              const SizedBox(height: 24),
              _buildTrafficPriority(isDark, pc),
            ],
            const SizedBox(height: 24),
            _buildSubscriptionCard(info, isDark, expiredAt, isValid, pc),
            const SizedBox(height: 24),
            _buildVpnCard(vpn, isDark, pc),
          ]);
        }),
      ]),
    );
  }

  // ─── Stats Row ───
  Widget _buildStatsRow(bool isDark, int balance, List<int>? stat) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 700 ? 4 : 2;
      final gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        _statCard('💰', '账户余额', '¥${(balance / 100).toStringAsFixed(2)}', w, isDark),
        _statCard('📦', '待处理订单', '${stat != null && stat.isNotEmpty ? stat[0] : 0}', w, isDark),
        _statCard('🎫', '开放工单', '${stat != null && stat.length > 1 ? stat[1] : 0}', w, isDark),
        _statCard('👥', '推荐人数', '${stat != null && stat.length > 2 ? stat[2] : 0}', w, isDark),
      ]);
    });
  }

  Widget _statCard(String emoji, String label, String value, double w, bool isDark) {
    return Container(
      width: w, padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.gray900)),
        ])),
      ]),
    );
  }

  // ─── 套餐流量 ───
  Widget _buildTrafficCircle(String title, double pct, int used, int total, bool isDark, Color pc) {
    final color = pct >= 80 ? AppColors.error : pct >= 50 ? AppColors.warning : AppColors.info;
    return Container(
      padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft,
          child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900))),
        const SizedBox(height: 16),
        SizedBox(width: 160, height: 160, child: CustomPaint(
          painter: _CirclePainter(pct / 100, color, isDark ? AppColors.gray700 : AppColors.gray200),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
            Text('已用', style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
          ])),
        )),
        const SizedBox(height: 16),
        Text('${TrafficFormatter.formatBytes(used)} / ${TrafficFormatter.formatBytes(total)}',
          style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray300 : AppColors.gray600)),
      ]),
    );
  }

  // ─── 流量包 ───
  Widget _buildPackageCircle(double pkgPct, int pkgUsed, int pkgTotal, bool isDark, Color pc) {
    final hasPackage = pkgTotal > 0;
    final color = !hasPackage ? (isDark ? AppColors.gray600 : AppColors.gray300)
        : pkgPct >= 80 ? AppColors.error : pkgPct >= 50 ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft,
          child: Text('流量包', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900))),
        const SizedBox(height: 16),
        SizedBox(width: 160, height: 160, child: CustomPaint(
          painter: _CirclePainter(hasPackage ? pkgPct / 100 : 0, color, isDark ? AppColors.gray700 : AppColors.gray200),
          child: Center(child: hasPackage
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${pkgPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
                Text('已用', style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
              ])
            : Text('未购买', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray500 : AppColors.gray400))),
        )),
        const SizedBox(height: 16),
        hasPackage
          ? Text('${TrafficFormatter.formatBytes(pkgUsed)} / ${TrafficFormatter.formatBytes(pkgTotal)}',
              style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray300 : AppColors.gray600))
          : GestureDetector(
              onTap: () => context.go('/traffic-packages'),
              child: Text('去购买流量包', style: TextStyle(fontSize: 14, color: pc, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ─── 流量消耗优先级 ───
  Widget _buildTrafficPriority(bool isDark, Color pc) {
    final priority = ref.watch(packageStatsProvider).priority;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), decoration: _cardDeco(isDark),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: pc.withValues(alpha: 0.08)),
          child: Icon(Icons.tune, size: 20, color: pc)),
        const SizedBox(width: 12),
        Expanded(child: Row(children: [
          Text('流量消耗顺序', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(width: 8),
          Flexible(child: Text(
            priority == 'plan' ? '先消耗套餐流量，用完再消耗流量包' : '先消耗流量包，用完再消耗套餐流量',
            style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray500 : AppColors.gray400),
            overflow: TextOverflow.ellipsis)),
        ])),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: isDark ? AppColors.gray700 : AppColors.gray100, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            _priorityBtn('套餐优先', 'plan', priority, isDark),
            _priorityBtn('流量包优先', 'package', priority, isDark),
          ]),
        ),
      ]),
    );
  }

  Widget _priorityBtn(String label, String value, String current, bool isDark) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => ref.read(packageStatsProvider.notifier).setPriority(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? (isDark ? AppColors.gray600 : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
          color: selected ? (isDark ? Colors.white : AppColors.gray900) : (isDark ? AppColors.gray400 : AppColors.gray500))),
      ),
    );
  }

  // ─── 订阅卡 ───
  Widget _buildSubscriptionCard(dynamic info, bool isDark, int expiredAt, bool isValid, Color pc) {
    return Container(
      padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('订阅', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 16),
        _infoRow('套餐', info?.plan?.name ?? '无', isDark),
        const SizedBox(height: 12),
        _infoRow('到期时间', _formatDate(expiredAt), isDark),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('状态', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
          Text(isValid ? '有效' : '已过期', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
            color: isValid ? AppColors.success : AppColors.error)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: SizedBox(height: 40, child: ElevatedButton(
            onPressed: () {
              if (info?.subscribeUrl != null) {
                Clipboard.setData(ClipboardData(text: info.subscribeUrl));
                setState(() => _copied = true);
                Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = false); });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: pc, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_copied ? '已复制！' : '复制订阅链接', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ))),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 40, child: OutlinedButton(
            onPressed: () => context.go('/plans'),
            style: OutlinedButton.styleFrom(foregroundColor: pc, side: BorderSide(color: pc),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('续费', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ))),
        ]),
      ]),
    );
  }

  // ─── VPN 连接卡 ───
  Widget _buildVpnCard(VpnState vpn, bool isDark, Color pc) {
    final isOn = vpn.isConnected;
    final isTransit = vpn.status == VpnStatus.connecting || vpn.status == VpnStatus.disconnecting;
    final statusColor = isOn ? AppColors.success : isTransit ? AppColors.warning : AppColors.gray300;
    final statusLabel = switch (vpn.status) {
      VpnStatus.connected => '已连接',
      VpnStatus.connecting => '连接中...',
      VpnStatus.disconnecting => '断开中...',
      VpnStatus.disconnected => '未连接',
    };

    return Container(
      padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: title + status badge
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('VPN 连接', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.gray900)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isOn ? const Color(0xFFDCFCE7) : (isDark ? AppColors.gray700 : AppColors.gray100),
              borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: statusColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // Power button
        Center(child: GestureDetector(
          onTap: isTransit ? null : () async {
            final n = ref.read(vpnStateProvider.notifier);
            if (vpn.isConnected) {
              n.disconnect();
            } else {
              // Ensure subscription info is loaded, then fetch mihomo config.
              final subNotifier = ref.read(subscriptionProvider.notifier);
              if (ref.read(subscriptionProvider).info?.subscribeUrl == null) {
                await subNotifier.fetchSubscription();
              }
              String? config = ref.read(subscriptionProvider).mihomoConfig;
              if (config == null || config.isEmpty) {
                await subNotifier.fetchMihomoConfig();
                config = ref.read(subscriptionProvider).mihomoConfig;
              }
              if (config == null || config.isEmpty) {
                if (mounted) showTopToast(context, '获取订阅配置失败', isError: true);
                return;
              }
              final ok = await n.connect(config);
              if (!ok) {
                if (mounted) {
                  final err = ref.read(vpnStateProvider).errorMessage;
                  showTopToast(context, err ?? '启动 mihomo 失败', isError: true);
                }
                return;
              }
              // Wait for Clash API ready.
              for (var i = 0; i < 20; i++) {
                await Future.delayed(const Duration(milliseconds: 500));
                if (ref.read(vpnStateProvider).isConnected) break;
              }
              if (!mounted || !ref.read(vpnStateProvider).isConnected) return;

              // Load proxy groups and sync to Riverpod state immediately.
              await n.refreshProxies();

              // Find and select a real proxy node.
              // Skip info nodes injected by the panel (e.g. "剩余流量：…",
              // "套餐到期：…") — they sit at the front of the proxy list
              // but aren't real server nodes.
              final group = n.primaryGroup;
              String? testNode;
              if (group != null) {
                final vpnState = ref.read(vpnStateProvider);
                final groupInfo = vpnState.proxyGroups
                    .where((g) => g.name == group)
                    .firstOrNull;
                if (groupInfo != null) {
                  // The proxy group's all list mirrors the Clash config
                  // ordering.  Pick the first member that is a real proxy
                  // (exists in the proxies list), skipping sub-groups and
                  // info nodes whose names contain Chinese punctuation
                  // patterns like "：" that real server names don't have.
                  final proxyNames =
                      vpnState.proxies.map((p) => p.name).toSet();
                  const infoPatterns = ['剩余流量', '套餐到期', '过滤掉', '距离下次重置'];
                  const builtins = ['DIRECT', 'REJECT', 'COMPATIBLE', 'Compatible'];
                  for (final member in groupInfo.all) {
                    if (!proxyNames.contains(member)) continue;
                    if (builtins.contains(member)) continue;
                    if (infoPatterns.any((p) => member.contains(p))) continue;
                    testNode = member;
                    break;
                  }
                  // Fallback: use the group's current selection if our
                  // filter found nothing.
                  testNode ??= groupInfo.now;
                }
                if (testNode != null) {
                  await n.selectNode(group, testNode);
                }
              }
              testNode ??= ref.read(vpnStateProvider).currentNode;
              if (testNode == null) return;

              // Verify the proxy works (retry once — mihomo may still be warming up).
              var delay = await n.testDelay(testNode);
              if (delay < 0) {
                await Future.delayed(const Duration(seconds: 2));
                delay = await n.testDelay(testNode);
              }
              if (!mounted) return;
              if (delay < 0) {
                showTopToast(context, '已连接但代理不通，请检查网络或防火墙', isError: true);
              } else {
                showTopToast(context, '已连接到 $testNode（${delay}ms）');
              }
            }
          },
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.1),
              border: Border.all(color: statusColor, width: 2.5)),
            child: Icon(Icons.power_settings_new, color: statusColor, size: 32),
          ),
        )),
        const SizedBox(height: 8),
        Center(child: Text(isOn ? '点击断开' : '点击连接',
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.gray400 : AppColors.gray500))),

        // Error message
        if (vpn.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(vpn.errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
              textAlign: TextAlign.center),
          ),
        ],

        const SizedBox(height: 20),
        // Speed monitor
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.gray700.withValues(alpha: 0.5) : AppColors.gray50,
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: _speedItem(Icons.arrow_upward, '上传', vpn.uploadSpeed, isDark)),
            Container(width: 1, height: 36, color: isDark ? AppColors.gray600 : AppColors.gray200),
            Expanded(child: _speedItem(Icons.arrow_downward, '下载', vpn.downloadSpeed, isDark)),
          ]),
        ),
      ]),
    );
  }

  Widget _speedItem(IconData icon, String label, int bytesPerSec, bool isDark) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: isDark ? AppColors.gray400 : AppColors.gray500),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
      ]),
      const SizedBox(height: 4),
      Text(TrafficFormatter.formatSpeed(bytesPerSec),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.gray900)),
    ]);
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.gray900)),
    ]);
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.gray800 : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );
}

class _CirclePainter extends CustomPainter {
  final double progress; final Color color; final Color bg;
  _CirclePainter(this.progress, this.color, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = bg..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * progress, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _CirclePainter old) => old.progress != progress || old.color != color;
}
