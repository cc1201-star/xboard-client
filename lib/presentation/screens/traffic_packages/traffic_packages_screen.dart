import 'package:xboard_client/presentation/widgets/top_toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/core/utils/traffic_formatter.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TrafficPackagesScreen extends ConsumerStatefulWidget {
  const TrafficPackagesScreen({super.key});
  @override
  ConsumerState<TrafficPackagesScreen> createState() => _TrafficPackagesScreenState();
}

class _TrafficPackagesScreenState extends ConsumerState<TrafficPackagesScreen> {
  String _tab = 'buy';
  List<dynamic> _packages = [];
  List<dynamic> _myPackages = [];
  bool _loading = true;
  String? _error;
  bool _purchasing = false;
  int? _purchasingId;
  // Payment modal
  Map<String, dynamic>? _paymentModal;
  List<dynamic> _paymentMethods = [];
  int? _selectedMethodId;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([client.getTrafficPackages(), client.getMyPackages()]);
      setState(() {
        _packages = results[0].data['data'] as List? ?? [];
        _myPackages = results[1].data['data'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = '加载失败'; });
    }
  }

  Future<void> _purchase(int id, String name) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() { _purchasing = true; _purchasingId = id; });
    try {
      final resp = await client.purchasePackage(id);
      final data = resp.data['data'];
      // API returns trade_no as string directly, or as object
      final tradeNo = data is String ? data : (data is Map ? data['trade_no'] as String? : null);

      if (tradeNo != null && tradeNo.isNotEmpty) {
        // Check if order is already paid (free package)
        final checkResp = await client.checkOrder(tradeNo);
        if (checkResp.data['data'] == 3) {
          await _fetchAll();
          if (mounted) showTopToast(context, '购买成功！');
        } else {
          // Need payment — show payment modal
          final methodResp = await client.getPaymentMethods();
          setState(() {
            _paymentModal = {'trade_no': tradeNo, 'packageName': name};
            _paymentMethods = methodResp.data['data'] as List? ?? [];
            _selectedMethodId = _paymentMethods.isNotEmpty ? _paymentMethods[0]['id'] as int : null;
          });
        }
      } else {
        // No trade_no — purchase succeeded directly
        await _fetchAll();
        if (mounted) showTopToast(context, '购买成功！');
      }
    } catch (_) {
      if (mounted) showTopToast(context, '购买失败', isError: true);
    }
    if (mounted) setState(() { _purchasing = false; _purchasingId = null; });
  }

  Future<void> _checkoutPackage() async {
    if (_paymentModal == null || _selectedMethodId == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() => _paying = true);
    try {
      final resp = await client.checkout(_paymentModal!['trade_no'], _selectedMethodId!);
      final data = resp.data['data'];
      final type = data?['type'] ?? 0;

      if (type == -1) {
        setState(() { _paymentModal = null; _paying = false; });
        await _fetchAll();
        if (mounted) showTopToast(context, '支付成功！');
      } else if (type == 1 && data?['data'] != null) {
        setState(() { _paymentModal = null; _paying = false; });
        launchUrl(Uri.parse(data['data']), mode: LaunchMode.externalApplication);
      } else {
        setState(() { _paymentModal = null; _paying = false; });
      }
    } catch (_) {
      setState(() => _paying = false);
    }
  }

  Future<void> _reorderPackage(List<dynamic> active, int fromIndex, int toIndex) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    final ids = active.map((p) => (p as Map<String, dynamic>)['id'] as int).toList();
    final item = ids.removeAt(fromIndex);
    ids.insert(toIndex, item);
    try {
      await client.reorderPackages(ids);
      await _fetchAll();
    } catch (_) {}
  }

  Future<void> _toggleAutoRenew(int id, bool currentValue) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      await client.toggleAutoRenew(id, !currentValue);
      await _fetchAll();
    } catch (_) {}
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Center(child: SizedBox(width: 32, height: 32,
        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)));
    }

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('流量包', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 24),

          if (_error != null) _buildErrorBanner(isDark),

          // Tabs
          Row(children: [
            _tabBtn('购买流量包', 'buy', isDark),
            const SizedBox(width: 8),
            _tabBtn('我的流量包 (${_myPackages.length})', 'my', isDark),
          ]),
          const SizedBox(height: 24),

          if (_tab == 'buy') _buildBuyTab(isDark),
          if (_tab == 'my') _buildMyTab(isDark),
        ]),
      ),
      if (_paymentModal != null) _buildPaymentModal(isDark),
    ]);
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x337F1D1D) : const Color(0xFFFEF2F2),
        border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Text(_error!, style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)))),
        GestureDetector(
          onTap: _fetchAll,
          child: Text('重试', style: TextStyle(fontSize: 14, decoration: TextDecoration.underline,
            color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))),
        ),
      ]),
    );
  }

  Widget _tabBtn(String text, String tab, bool isDark) {
    final active = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray800 : Colors.white),
          borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
          color: active ? Colors.white : (isDark ? AppColors.gray300 : AppColors.gray700))),
      ),
    );
  }

  Widget _buildBuyTab(bool isDark) {
    if (_packages.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(48),
        decoration: _cardDeco(isDark),
        child: Text('暂无可购买的流量包', textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray500)),
      );
    }

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
      final gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;

      // Build card widgets
      final cards = _packages.map((p) {
        final pkg = p as Map<String, dynamic>;
        final gb = ((pkg['traffic_bytes'] as num? ?? pkg['transfer_enable'] as num? ?? 0) / (1024 * 1024 * 1024)).round();
        final price = (pkg['price'] as num? ?? 0) / 100;
        final days = pkg['duration_days'] as int?;
        final id = pkg['id'] as int;
        final pc = Theme.of(context).colorScheme.primary;

        return SizedBox(
          width: w,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: _cardDeco(isDark),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: pc.withValues(alpha: 0.1)),
                child: Icon(Icons.download, size: 32, color: pc),
              ),
              const SizedBox(height: 16),
              Text('$gb GB', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 4),
              Text(days != null ? '${days}天有效' : '永久有效，用完为止',
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
              const SizedBox(height: 4),
              // 统一占位：有单价显示单价，没单价显示空行保持等高
              Text(price > 0 && gb > 0 ? '¥${(price / gb).toStringAsFixed(2)}/GB' : ' ',
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray500 : AppColors.gray400)),
              const Spacer(),
              Text(price > 0 ? '¥${price.toStringAsFixed(0)}' : '免费',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: pc)),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 44, child: ElevatedButton(
                onPressed: (_purchasing && _purchasingId == id) ? null : () => _purchase(id, '$gb GB'),
                style: ElevatedButton.styleFrom(backgroundColor: pc, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text((_purchasing && _purchasingId == id) ? '处理中...' : '立即购买'),
              )),
            ]),
          ),
        );
      }).toList();

      // 按行分组，每行用 IntrinsicHeight 等高
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += cols) {
        final rowCards = cards.sublist(i, (i + cols).clamp(0, cards.length));
        // 不满一行时，补空的 Expanded 占位，保持左对齐
        final children = <Widget>[];
        for (var j = 0; j < cols; j++) {
          if (j > 0) children.add(SizedBox(width: gap));
          if (j < rowCards.length) {
            children.add(Expanded(child: rowCards[j]));
          } else {
            children.add(const Expanded(child: SizedBox.shrink()));
          }
        }
        rows.add(IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        )));
        if (i + cols < cards.length) rows.add(SizedBox(height: gap));
      }
      return Column(children: rows);
    });
  }

  Widget _buildMyTab(bool isDark) {
    if (_myPackages.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(48),
        decoration: _cardDeco(isDark),
        child: Column(children: [
          Text('暂无流量包，去购买一个吧', style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _tab = 'buy'),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('去购买'),
          ),
        ]),
      );
    }

    final active = _myPackages.where((p) => (p['status'] as int?) != 2).toList();
    final depleted = _myPackages.where((p) => (p['status'] as int?) == 2).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (active.length > 1)
        Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text('使用上下箭头调整流量包的消耗顺序，排在前面的先消耗',
            style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500))),
      // Active packages
      ...active.asMap().entries.map((e) {
        final pkg = e.value as Map<String, dynamic>;
        final usedBytes = (pkg['used_bytes'] as num? ?? 0).toInt();
        final totalBytes = (pkg['traffic_bytes'] as num? ?? pkg['total_bytes'] as num? ?? 0).toInt();
        final remainingBytes = (pkg['remaining_bytes'] as num? ?? (totalBytes - usedBytes).clamp(0, totalBytes)).toInt();
        final pct = totalBytes > 0 ? (usedBytes / totalBytes * 100).clamp(0, 100) : 0.0;
        final autoRenew = pkg['auto_renew'] == true || pkg['auto_renew'] == 1;

        return Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                // Reorder arrows
                if (active.length > 1) ...[
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: e.key > 0 ? () => _reorderPackage(active, e.key, e.key - 1) : null,
                      child: Opacity(opacity: e.key > 0 ? 1 : 0.2,
                        child: Padding(padding: const EdgeInsets.all(2),
                          child: Icon(Icons.keyboard_arrow_up, size: 14,
                            color: isDark ? AppColors.gray400 : AppColors.gray600))),
                    ),
                    GestureDetector(
                      onTap: e.key < active.length - 1 ? () => _reorderPackage(active, e.key, e.key + 1) : null,
                      child: Opacity(opacity: e.key < active.length - 1 ? 1 : 0.2,
                        child: Padding(padding: const EdgeInsets.all(2),
                          child: Icon(Icons.keyboard_arrow_down, size: 14,
                            color: isDark ? AppColors.gray400 : AppColors.gray600))),
                    ),
                  ]),
                  const SizedBox(width: 8),
                ],
                Text(pkg['name'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray900)),
                if (active.length > 1) ...[
                  const SizedBox(width: 8),
                  Text('#${e.key + 1}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray500 : AppColors.gray400)),
                ],
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x4D166534) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20)),
                child: Text('使用中', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
              ),
            ]),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: pct / 100,
                minHeight: 10, backgroundColor: isDark ? AppColors.gray700 : AppColors.gray200,
                valueColor: const AlwaysStoppedAnimation(AppColors.info))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('已用 ${TrafficFormatter.formatBytes(usedBytes)}',
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
              Text('剩余 ${TrafficFormatter.formatBytes(remainingBytes)} / ${TrafficFormatter.formatBytes(totalBytes)}',
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('购买时间：${_formatDate(pkg['created_at'])}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray500 : AppColors.gray400)),
              Text(pkg['expired_at'] != null ? '到期：${_formatDate(pkg['expired_at'])}' : '永久有效',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray500 : AppColors.gray400)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(
                color: isDark ? AppColors.gray700 : AppColors.gray100))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text('自动续费', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray300 : AppColors.gray600)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _toggleAutoRenew(pkg['id'] as int, autoRenew),
                    child: Container(
                      width: 44, height: 24,
                      decoration: BoxDecoration(
                        color: autoRenew ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray600 : AppColors.gray300),
                        borderRadius: BorderRadius.circular(12)),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: autoRenew ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(width: 20, height: 20, margin: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                ]),
                GestureDetector(
                  onTap: () => _purchase(pkg['traffic_package_id'] as int? ?? pkg['id'] as int, pkg['name'] ?? ''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: Text('再次购买', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
              ]),
            ),
          ]),
        );
      }),

      // Depleted packages
      if (depleted.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('已用完', style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray500 : AppColors.gray400)),
        const SizedBox(height: 8),
        ...depleted.map((p) {
          final pkg = p as Map<String, dynamic>;
          final usedBytes = (pkg['used_bytes'] as num? ?? 0).toInt();
          final totalBytes = (pkg['traffic_bytes'] as num? ?? pkg['total_bytes'] as num? ?? 0).toInt();

          return Opacity(opacity: 0.6, child: Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(pkg['name'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray900)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.gray700 : AppColors.gray100,
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('已用完', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.gray400 : AppColors.gray500)),
                ),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: 1.0, minHeight: 10,
                  backgroundColor: isDark ? AppColors.gray700 : AppColors.gray200,
                  valueColor: AlwaysStoppedAnimation(AppColors.info.withValues(alpha: 0.4)))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('已用 ${TrafficFormatter.formatBytes(usedBytes)}',
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
                Text(TrafficFormatter.formatBytes(totalBytes),
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
              ]),
              Container(
                margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(
                  color: isDark ? AppColors.gray700 : AppColors.gray100))),
                child: Align(alignment: Alignment.centerRight, child: GestureDetector(
                  onTap: () => _purchase(pkg['traffic_package_id'] as int? ?? pkg['id'] as int, pkg['name'] ?? ''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('再次购买', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary)),
                  ),
                )),
              ),
            ]),
          ));
        }),
      ],
    ]);
  }

  Widget _buildPaymentModal(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() { _paymentModal = null; _selectedMethodId = null; }),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 400, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? AppColors.gray800 : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('支付：${_paymentModal!['packageName']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 16),
              Text('选择支付方式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.gray300 : AppColors.gray700)),
              const SizedBox(height: 8),
              ..._paymentMethods.map((m) {
                final method = m as Map<String, dynamic>;
                final id = method['id'] as int;
                final selected = _selectedMethodId == id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMethodId = id),
                  child: Container(
                    width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray600 : AppColors.gray200), width: 2),
                      color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent),
                    child: Row(children: [
                      Text(method['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.gray900)),
                      if (method['handling_fee_percent'] != null && (method['handling_fee_percent'] as num) > 0) ...[
                        const SizedBox(width: 8),
                        Text('+${method['handling_fee_percent']}%', style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
                      ],
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: SizedBox(height: 44, child: OutlinedButton(
                  onPressed: () => setState(() { _paymentModal = null; _selectedMethodId = null; }),
                  style: OutlinedButton.styleFrom(foregroundColor: isDark ? AppColors.gray300 : AppColors.gray700,
                    side: BorderSide(color: isDark ? AppColors.gray600 : AppColors.gray300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('取消'),
                ))),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: 44, child: ElevatedButton(
                  onPressed: _paying ? null : _checkoutPackage,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(_paying ? '处理中...' : '确认支付'),
                ))),
              ]),
            ]),
          ),
        )),
      ),
    );
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.gray800 : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );
}
