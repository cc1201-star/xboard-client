import 'package:xboard_client/presentation/widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/providers/user_provider.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});
  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  List<dynamic> _plans = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedPlan;
  String? _selectedPeriod;
  bool _ordering = false;

  static const _periodLabels = {
    'month_price': '月付',
    'quarter_price': '季付',
    'half_year_price': '半年付',
    'year_price': '年付',
    'two_year_price': '两年付',
    'three_year_price': '三年付',
    'onetime_price': '一次性',
    'reset_price': '重置流量',
  };

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getPlans();
      setState(() {
        _plans = resp.data['data'] as List? ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<MapEntry<String, int>> _getAvailablePrices(Map<String, dynamic> plan) {
    final prices = <MapEntry<String, int>>[];
    for (final key in _periodLabels.keys) {
      final val = plan[key];
      if (val != null && val is num && val > 0) {
        prices.add(MapEntry(key, val.toInt()));
      }
    }
    return prices;
  }

  Future<void> _submitOrder() async {
    if (_selectedPlan == null || _selectedPeriod == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() => _ordering = true);
    try {
      await client.saveOrder(_selectedPlan!['id'] as int, _selectedPeriod!);
      if (mounted) {
        setState(() { _selectedPlan = null; _selectedPeriod = null; _ordering = false; });
        context.go('/orders');
      }
    } catch (e) {
      setState(() => _ordering = false);
      if (mounted) {
        showTopToast(context, '下单失败', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProvider).user;

    if (_loading) {
      return Center(child: SizedBox(width: 32, height: 32,
        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)));
    }

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('套餐', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
            final gap = 24.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap,
              children: _plans.map((p) => _buildPlanCard(p as Map<String, dynamic>, w, isDark, user?.planId)).toList());
          }),
        ]),
      ),
      if (_selectedPlan != null) _buildOrderModal(isDark),
    ]);
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, double w, bool isDark, int? currentPlanId) {
    final isCurrent = currentPlanId == plan['id'];
    final prices = _getAvailablePrices(plan);
    final transferGb = ((plan['transfer_enable'] as num? ?? 0) / (1024 * 1024 * 1024)).round();

    return Container(
      width: w,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.gray800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(plan['name'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900))),
          if (isCurrent) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)),
            child: const Text('当前套餐', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ]),
        if (plan['description'] != null && (plan['description'] as String).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(plan['description'], style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
        ],
        const SizedBox(height: 16),
        _featureItem('流量：$transferGb GB', isDark),
        if (plan['speed_limit'] != null) _featureItem('速度：${plan['speed_limit']} Mbps', isDark),
        if (plan['device_limit'] != null) _featureItem('设备数：${plan['device_limit']}', isDark),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: prices.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.gray700.withValues(alpha: 0.5) : AppColors.gray50,
            borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(_periodLabels[e.key]!, style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
            Text('¥${(e.value / 100).toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.gray900)),
          ]),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 44, child: ElevatedButton(
          onPressed: () {
            final avail = _getAvailablePrices(plan);
            setState(() {
              _selectedPlan = plan;
              _selectedPeriod = avail.isNotEmpty ? avail.first.key : null;
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('选择套餐', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        )),
      ]),
    );
  }

  Widget _featureItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray300 : AppColors.gray600)),
      ]),
    );
  }

  Widget _buildOrderModal(bool isDark) {
    final prices = _getAvailablePrices(_selectedPlan!);

    return GestureDetector(
      onTap: () => setState(() { _selectedPlan = null; _selectedPeriod = null; }),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 400, margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.gray800 : Colors.white,
              borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('下单：${_selectedPlan!['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 16),
              Text('付费周期', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.gray300 : AppColors.gray700)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.gray700 : AppColors.gray100,
                  borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.gray700 : Colors.white,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900),
                  items: prices.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('${_periodLabels[e.key]} - ¥${(e.value / 100).toStringAsFixed(2)}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedPeriod = v),
                )),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: SizedBox(height: 44, child: OutlinedButton(
                  onPressed: () => setState(() { _selectedPlan = null; _selectedPeriod = null; }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.gray300 : AppColors.gray700,
                    side: BorderSide(color: isDark ? AppColors.gray600 : AppColors.gray300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('取消', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ))),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: 44, child: ElevatedButton(
                  onPressed: _ordering ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(_ordering ? '处理中...' : '立即购买', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ))),
              ]),
            ]),
          ),
        )),
      ),
    );
  }
}
