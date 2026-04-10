import 'package:xboard_client/presentation/widgets/top_toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/providers/user_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RechargeScreen extends ConsumerStatefulWidget {
  const RechargeScreen({super.key});
  @override
  ConsumerState<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends ConsumerState<RechargeScreen> {
  int _amountInCents = 0;
  bool _isCustom = false;
  final _customController = TextEditingController();
  List<dynamic> _paymentMethods = [];
  int? _selectedMethodId;
  bool _submitting = false;
  bool _loading = true;

  static const _presets = [1000, 5000, 10000, 50000]; // cents

  @override
  void initState() {
    super.initState();
    _fetchPaymentMethods();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).fetchUser();
    });
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentMethods() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getPaymentMethods();
      setState(() {
        _paymentMethods = resp.data['data'] as List? ?? [];
        if (_paymentMethods.isNotEmpty) _selectedMethodId = _paymentMethods[0]['id'] as int;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_amountInCents <= 0 || _selectedMethodId == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() => _submitting = true);
    try {
      final resp = await client.saveRechargeOrder(_amountInCents, 'onetime_price');
      final data = resp.data['data'];
      if (data != null && data['trade_no'] != null) {
        final checkoutResp = await client.checkout(data['trade_no'], _selectedMethodId!);
        final checkoutData = checkoutResp.data['data'];
        final type = checkoutData?['type'] ?? 0;

        if (type == -1) {
          await ref.read(userProvider.notifier).fetchUser();
          if (mounted) showTopToast(context, '充值成功！');
        } else if (type == 1 && checkoutData?['data'] != null) {
          launchUrl(Uri.parse(checkoutData['data']), mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      if (mounted) showTopToast(context, '充值失败', isError: true);
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProvider).user;
    final balance = user?.balance ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('充值', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 24),

          // Balance card
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: _cardDeco(isDark),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('当前余额', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('¥', style: TextStyle(fontSize: 20, color: isDark ? Colors.white : AppColors.gray900)),
                Text((balance / 100).toStringAsFixed(2), style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.gray900)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // Amount selection
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: _cardDeco(isDark),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('充值金额', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 16),
              // Preset amounts
              LayoutBuilder(builder: (_, c) {
                final cols = c.maxWidth > 400 ? 4 : 2;
                final gap = 12.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(spacing: gap, runSpacing: gap, children: _presets.map((cents) {
                  final selected = !_isCustom && _amountInCents == cents;
                  return GestureDetector(
                    onTap: () => setState(() { _isCustom = false; _amountInCents = cents; }),
                    child: Container(
                      width: w, padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray600 : AppColors.gray200), width: 2),
                        color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent),
                      child: Column(children: [
                        Text('${cents ~/ 100}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.gray900)),
                        const SizedBox(height: 2),
                        Text('元', style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
                      ]),
                    ),
                  );
                }).toList());
              }),
              const SizedBox(height: 16),
              // Custom amount toggle
              GestureDetector(
                onTap: () => setState(() { _isCustom = !_isCustom; if (!_isCustom) _amountInCents = 0; }),
                child: Text('自定义金额', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: _isCustom ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray400 : AppColors.gray500))),
              ),
              if (_isCustom) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '¥ ',
                    prefixStyle: TextStyle(color: AppColors.gray400, fontWeight: FontWeight.w500),
                    hintText: '10 - 500',
                    filled: true,
                    fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                  ),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.gray900),
                  onChanged: (v) {
                    final val = int.tryParse(v) ?? 0;
                    setState(() => _amountInCents = val.clamp(0, 500) * 100);
                  },
                ),
              ],
            ]),
          ),
          const SizedBox(height: 24),

          // Payment methods
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: _cardDeco(isDark),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('支付方式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 16),
              if (_paymentMethods.isEmpty)
                Text('暂无可用支付方式', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500))
              else ..._paymentMethods.map((m) {
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
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(method['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.gray900)),
                      if (selected) Icon(Icons.check_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                    ]),
                  ),
                );
              }),
            ]),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: (_submitting || _amountInCents <= 0 || _selectedMethodId == null) ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
              disabledBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(
              _submitting ? '处理中...' :
              _amountInCents > 0 ? '确认充值 ¥${(_amountInCents / 100).toStringAsFixed(2)}' : '请选择充值金额',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          )),
        ]),
      ),
    );
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.gray800 : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );
}
