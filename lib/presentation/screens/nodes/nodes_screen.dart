import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/providers/subscription_provider.dart';
import 'package:xboard_client/presentation/providers/vpn_state_provider.dart';
import 'package:xboard_client/presentation/widgets/top_toast.dart';

// The primary proxy group name is discovered dynamically from mihomo runtime
// (see VpnNotifier.primaryGroup). No longer hardcoded.

class NodesScreen extends ConsumerStatefulWidget {
  const NodesScreen({super.key});

  @override
  ConsumerState<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends ConsumerState<NodesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _nodes = [];
  String? _pendingNodeName;
  // Latency per node name, in milliseconds. -1 means timeout / unreachable.
  final Map<String, int> _delays = {};
  bool _testingAll = false;
  final ScrollController _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await client.getServerList();
      final raw = resp.data['data'] as List? ?? [];
      setState(() {
        _nodes = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = '加载节点失败';
        _loading = false;
      });
    }
  }

  Future<void> _onTapNode(Map<String, dynamic> node) async {
    if (kIsWeb) {
      _toast('此平台不支持 VPN 连接，请下载桌面或手机客户端', isError: true);
      return;
    }

    final name = node['name'] as String? ?? '';
    if (name.isEmpty) return;

    final notifier = ref.read(vpnStateProvider.notifier);
    final subNotifier = ref.read(subscriptionProvider.notifier);
    final vpn = ref.read(vpnStateProvider);

    // Tapping the currently active node → disconnect.
    if (vpn.currentNode == name && vpn.isConnected) {
      await notifier.disconnect();
      _toast('已断开');
      return;
    }

    setState(() => _pendingNodeName = name);
    try {
      // Always fetch fresh config to pick up server-side changes.
      if (ref.read(subscriptionProvider).info?.subscribeUrl == null) {
        await subNotifier.fetchSubscription();
      }
      final url = ref.read(subscriptionProvider).info?.subscribeUrl;
      if (url == null || url.isEmpty) {
        _toast('获取订阅地址失败，请先在仪表盘确认订阅状态', isError: true);
        return;
      }
      await subNotifier.fetchMihomoConfig();
      var config = ref.read(subscriptionProvider).mihomoConfig;
      if (config == null || config.isEmpty) {
        _toast('下载订阅配置失败 (URL: $url)', isError: true);
        return;
      }

      if (vpn.isConnected) {
        await notifier.disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final ok = await notifier.connect(config);
      if (ok == false) {
        final err = ref.read(vpnStateProvider).errorMessage;
        _toast(err ?? '启动 mihomo 失败', isError: true);
        return;
      }

      // Wait for actual connection (Clash API verified).
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final cur = ref.read(vpnStateProvider);
        if (cur.isConnected) {
          final group = notifier.primaryGroup;
          if (group == null) {
            _toast('未找到可用的代理组，请检查订阅配置', isError: true);
            return;
          }
          final selectErr = await notifier.selectNode(group, name);
          if (selectErr != null) {
            _toast('切换节点失败: $selectErr', isError: true);
            return;
          }
          // Verify the proxy actually works by testing delay.
          final delay = await notifier.testDelay(name);
          if (delay < 0) {
            _toast('已连接到 $name，但代理不通（测速超时），请检查网络或防火墙', isError: true);
            return;
          }
          _toast('已连接到 $name（${delay}ms）');
          return;
        }
        if (cur.errorMessage != null) {
          _toast(cur.errorMessage!, isError: true);
          return;
        }
      }

      final err = ref.read(vpnStateProvider).errorMessage;
      _toast(err ?? '连接超时(等待Clash API 10秒无响应)', isError: true);
    } catch (e) {
      _toast('连接失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _pendingNodeName = null);
    }
  }

  /// Scroll the list to the currently active (connected) node.
  void _locateCurrent() {
    final vpn = ref.read(vpnStateProvider);
    if (!vpn.isConnected || vpn.currentNode == null) {
      _toast('当前未连接任何节点');
      return;
    }
    final key = _cardKeys[vpn.currentNode!];
    final ctx = key?.currentContext;
    if (ctx == null) {
      _toast('未在列表中找到当前节点');
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  /// Probe every node's latency via the Clash API. Requires mihomo to be
  /// running — if it's not, prompt the user to connect first.
  Future<void> _testAll() async {
    if (kIsWeb) {
      _toast('Web 端不支持测速', isError: true);
      return;
    }
    final vpn = ref.read(vpnStateProvider);
    if (!vpn.isConnected) {
      _toast('请先连接任一节点再测速', isError: true);
      return;
    }
    if (_testingAll) return;
    setState(() => _testingAll = true);

    final notifier = ref.read(vpnStateProvider.notifier);
    // Kick off one request per node in parallel; update state as each returns.
    final futures = <Future<void>>[];
    for (final n in _nodes) {
      final name = n['name'] as String? ?? '';
      if (name.isEmpty) continue;
      setState(() => _delays[name] = -2); // sentinel: 正在测
      futures.add(notifier.testDelay(name).then((ms) {
        if (mounted) {
          setState(() => _delays[name] = ms);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _delays[name] = -1);
        }
      }));
    }
    await Future.wait(futures);
    if (mounted) setState(() => _testingAll = false);
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    showTopToast(context, msg, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final vpn = ref.watch(vpnStateProvider);

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '节点',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.gray900,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '定位当前节点',
                onPressed: _locateCurrent,
                icon: Icon(
                  Icons.my_location,
                  color: isDark ? AppColors.gray300 : AppColors.gray600,
                ),
              ),
              IconButton(
                tooltip: _testingAll ? '测速中…' : '测所有节点网速',
                onPressed: _testingAll ? null : _testAll,
                icon: _testingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.speed,
                        color:
                            isDark ? AppColors.gray300 : AppColors.gray600,
                      ),
              ),
              IconButton(
                tooltip: '刷新节点列表',
                onPressed: _loading ? null : _fetch,
                icon: Icon(
                  Icons.refresh,
                  color: isDark ? AppColors.gray300 : AppColors.gray600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '点击节点即可连接，再次点击已连接的节点断开',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.gray400 : AppColors.gray500,
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            _buildEmpty(
              isDark,
              icon: Icons.error_outline,
              title: _error!,
              actionLabel: '重试',
              onAction: _fetch,
              primary: primary,
            )
          else if (_nodes.isEmpty)
            _buildEmpty(
              isDark,
              icon: Icons.dns_outlined,
              title: '暂无可用节点',
              subtitle: '请联系管理员或稍后再试',
            )
          else
            LayoutBuilder(
              builder: (_, c) {
                final cols = c.maxWidth > 1100
                    ? 3
                    : c.maxWidth > 720
                        ? 2
                        : 1;
                const gap = 20.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _nodes.map((n) {
                    final name = n['name'] as String? ?? '';
                    final key = _cardKeys.putIfAbsent(
                      name,
                      () => GlobalKey(debugLabel: 'node-$name'),
                    );
                    return _buildNodeCard(
                      n,
                      w,
                      isDark,
                      primary,
                      cardKey: key,
                      currentNode: vpn.currentNode,
                      isVpnConnected: vpn.isConnected,
                      isVpnConnecting: vpn.status == VpnStatus.connecting,
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(
    Map<String, dynamic> node,
    double w,
    bool isDark,
    Color primary, {
    required GlobalKey cardKey,
    required String? currentNode,
    required bool isVpnConnected,
    required bool isVpnConnecting,
  }) {
    final name = (node['name'] as String?) ?? '未命名';
    final type = (node['type'] as String?) ?? '';
    final rate = node['rate'];
    final rateStr = rate is num
        ? '${rate.toStringAsFixed(rate == rate.toInt() ? 0 : 1)}x'
        : '${rate ?? 1}x';
    final tags = (node['tags'] as List?)?.cast<dynamic>() ?? const [];

    final isActive = isVpnConnected && currentNode == name;
    final isPending = _pendingNodeName == name;
    final disabled = isPending ||
        (_pendingNodeName != null && _pendingNodeName != name) ||
        (isVpnConnecting && !isPending);

    // 两个状态: 未连接 = 灰色灯 + "离线",已连接 = 绿色灯 + "在线" + 卡片变灰
    final dotColor = isActive ? const Color(0xFF10B981) : AppColors.gray400;
    final statusText = isActive ? '在线' : '离线';
    final cardBg = isActive
        ? (isDark ? AppColors.gray700 : AppColors.gray100)
        : (isDark ? AppColors.gray800 : Colors.white);

    final delay = _delays[name];
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : () => _onTapNode(node),
        child: Container(
          width: w,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.gray900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    label: type.toUpperCase(),
                    color: primary.withValues(alpha: 0.12),
                    textColor: primary,
                  ),
                  _chip(
                    label: rateStr,
                    color: isDark
                        ? AppColors.gray700
                        : AppColors.gray100,
                    textColor: isDark
                        ? AppColors.gray300
                        : AppColors.gray600,
                  ),
                  ...tags.map(
                    (t) => _chip(
                      label: t.toString(),
                      color: isDark
                          ? AppColors.gray700
                          : AppColors.gray100,
                      textColor: isDark
                          ? AppColors.gray300
                          : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (isPending)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? const Color(0xFF10B981)
                            : AppColors.gray400,
                      ),
                    ),
                  const Spacer(),
                  _buildDelayBadge(delay, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDelayBadge(int? delay, bool isDark) {
    if (delay == null) return const SizedBox.shrink();
    if (delay == -2) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    if (delay < 0) {
      return Text(
        '超时',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.red.shade400,
        ),
      );
    }
    Color color;
    if (delay < 200) {
      color = const Color(0xFF10B981); // emerald
    } else if (delay < 500) {
      color = const Color(0xFFF59E0B); // amber
    } else {
      color = Colors.red.shade400;
    }
    return Text(
      '${delay}ms',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmpty(
    bool isDark, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    Color? primary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isDark ? AppColors.gray600 : AppColors.gray400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.gray300 : AppColors.gray600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.gray400 : AppColors.gray500,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary ?? AppColors.gray400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
