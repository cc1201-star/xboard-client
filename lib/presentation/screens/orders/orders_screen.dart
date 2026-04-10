import 'package:xboard_client/presentation/widgets/top_toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  Map<String, dynamic>? _payingOrder;
  List<dynamic> _paymentMethods = [];
  int? _selectedMethodId;
  bool _processing = false;
  String? _cancellingTradeNo;

  static const _statusLabels = {0: '待支付', 1: '处理中', 2: '已取消', 3: '已完成'};
  static const _periodMap = {
    'month_price': '月付', 'quarter_price': '季付', 'half_year_price': '半年付',
    'year_price': '年付', 'two_year_price': '两年付', 'three_year_price': '三年付',
    'onetime_price': '一次性', 'reset_price': '重置流量',
    'recharge': '余额充值', 'traffic_package': '流量包',
  };

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getOrders();
      setState(() { _orders = resp.data['data'] as List? ?? []; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancelOrder(String tradeNo) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() => _cancellingTradeNo = tradeNo);
    try {
      await client.cancelOrder(tradeNo);
      await _fetchOrders();
    } catch (_) {}
    if (mounted) setState(() => _cancellingTradeNo = null);
  }

  Future<void> _openPaymentModal(Map<String, dynamic> order) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getPaymentMethods();
      final methods = resp.data['data'] as List? ?? [];
      setState(() {
        _payingOrder = order;
        _paymentMethods = methods;
        _selectedMethodId = methods.isNotEmpty ? methods[0]['id'] as int : null;
      });
    } catch (_) {}
  }

  Future<void> _checkout() async {
    if (_payingOrder == null || _selectedMethodId == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    final tradeNo = _payingOrder!['trade_no'] as String;

    setState(() => _processing = true);
    try {
      final resp = await client.checkout(tradeNo, _selectedMethodId!);
      final data = resp.data['data'];
      final type = data?['type'] ?? 0;

      if (type == -1) {
        setState(() { _payingOrder = null; _processing = false; });
        await _fetchOrders();
        if (mounted) showTopToast(context, '支付成功！');
      } else if (type == 1 && data?['data'] != null) {
        setState(() { _payingOrder = null; _processing = false; });
        launchUrl(Uri.parse(data['data'] as String), mode: LaunchMode.externalApplication);
      } else if (data?['data'] != null) {
        setState(() { _payingOrder = null; _processing = false; });
        launchUrl(Uri.parse(data['data'] as String), mode: LaunchMode.externalApplication);
        _pollOrderStatus(tradeNo);
      } else {
        setState(() { _payingOrder = null; _processing = false; });
      }
    } catch (_) {
      setState(() => _processing = false);
    }
  }

  void _pollOrderStatus(String tradeNo) {
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || attempts >= 100) { timer.cancel(); return; }
      attempts++;
      try {
        final client = ref.read(apiClientProvider);
        final resp = await client?.checkOrder(tradeNo);
        if (resp?.data['data'] == 3) {
          timer.cancel();
          await _fetchOrders();
          if (mounted) showTopToast(context, '支付成功！');
        }
      } catch (_) {}
    });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getType(Map<String, dynamic> order) =>
    order['plan']?['name'] ?? _periodMap[order['period']] ?? '-';

  String _getPeriod(Map<String, dynamic> order) =>
    _periodMap[order['period']] ?? order['period'] ?? '-';

  String _getAmount(Map<String, dynamic> order) {
    final total = (order['total_amount'] as num? ?? 0) + (order['balance_amount'] as num? ?? 0);
    return '¥${(total / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pc = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return Center(child: SizedBox(width: 32, height: 32,
        child: CircularProgressIndicator(strokeWidth: 2, color: pc)));
    }

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('订单', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900)),
          const SizedBox(height: 24),
          if (_orders.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(48),
              decoration: _cardDeco(isDark),
              child: Text('暂无订单', textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray500)),
            )
          else
            LayoutBuilder(builder: (_, c) {
              if (c.maxWidth >= 768) return _desktopTable(isDark, pc);
              return _mobileCards(isDark, pc);
            }),
        ]),
      ),
      if (_payingOrder != null) _paymentModal(isDark, pc),
    ]);
  }

  // ─── Desktop: real HTML-table-like layout ───
  Widget _desktopTable(bool isDark, Color pc) {
    return Container(
      width: double.infinity,
      decoration: _cardDeco(isDark),
      clipBehavior: Clip.antiAlias,
      child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(2),   // 订单号
              1: FlexColumnWidth(1.2), // 类型
              2: FlexColumnWidth(1),   // 周期
              3: FlexColumnWidth(1),   // 金额
              4: FlexColumnWidth(1),   // 状态
              5: FlexColumnWidth(1.5), // 时间
              6: FlexColumnWidth(1.2), // 操作
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(
                  color: isDark ? AppColors.gray700 : AppColors.gray100))),
                children: [
                  _hCell('订单号', isDark, align: TextAlign.left),
                  _hCell('类型', isDark),
                  _hCell('周期', isDark),
                  _hCell('金额', isDark),
                  _hCell('状态', isDark),
                  _hCell('时间', isDark),
                  _hCell('操作', isDark),
                ],
              ),
              // Data rows
              ..._orders.map((o) {
                final order = o as Map<String, dynamic>;
                final status = order['status'] as int? ?? 0;
                return TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(
                    color: isDark ? AppColors.gray700.withValues(alpha: 0.5) : AppColors.gray50))),
                  children: [
                    // 订单号 - left aligned
                    _cell(Text(order['trade_no'] ?? '', style: TextStyle(fontSize: 14,
                      fontFamily: 'monospace', color: isDark ? Colors.white : AppColors.gray900))),
                    // 类型 - center
                    _cellCenter(Text(_getType(order), style: TextStyle(fontSize: 14,
                      color: isDark ? Colors.white : AppColors.gray900))),
                    // 周期 - center
                    _cellCenter(Text(_getPeriod(order), style: TextStyle(fontSize: 14,
                      color: isDark ? AppColors.gray300 : AppColors.gray600))),
                    // 金额 - center
                    _cellCenter(Text(_getAmount(order), style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.gray900))),
                    // 状态 - center, badge is inline
                    _cellCenter(_statusBadge(status, isDark)),
                    // 时间 - center
                    _cellCenter(Text(_formatDate(order['created_at']), style: TextStyle(fontSize: 14,
                      color: isDark ? AppColors.gray300 : AppColors.gray600))),
                    // 操作 - center
                    _cellCenter(status == 0 ? _actions(order, isDark, pc) : const SizedBox.shrink()),
                  ],
                );
              }),
            ],
          ),
    );
  }

  Widget _hCell(String text, bool isDark, {TextAlign align = TextAlign.center}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    child: Text(text, textAlign: align, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
      color: isDark ? AppColors.gray400 : AppColors.gray500)));

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: child);

  Widget _cellCenter(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    child: Center(child: child));

  Widget _actions(Map<String, dynamic> order, bool isDark, Color pc) {
    final tradeNo = order['trade_no'] as String;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => _openPaymentModal(order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: pc, borderRadius: BorderRadius.circular(8)),
          child: const Text('支付', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => _cancelOrder(tradeNo),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppColors.gray600 : AppColors.gray300)),
          child: Text(_cancellingTradeNo == tradeNo ? '取消中...' : '取消',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: isDark ? AppColors.gray400 : AppColors.gray600)),
        ),
      ),
    ]);
  }

  // ─── Mobile cards ───
  Widget _mobileCards(bool isDark, Color pc) {
    return Column(children: _orders.map((o) {
      final order = o as Map<String, dynamic>;
      final status = order['status'] as int? ?? 0;
      return Container(
        width: double.infinity, margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(isDark),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row 1: trade_no + status
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(order['trade_no'] ?? '', style: TextStyle(fontSize: 14,
              fontFamily: 'monospace', color: isDark ? Colors.white : AppColors.gray900),
              overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            _statusBadge(status, isDark),
          ]),
          const SizedBox(height: 12),
          // Row 2: type/period + amount
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_getType(order)} / ${_getPeriod(order)}',
              style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)),
            Text(_getAmount(order), style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.gray900)),
          ]),
          const SizedBox(height: 12),
          // Row 3: date + actions
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_formatDate(order['created_at']), style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
            if (status == 0) _actions(order, isDark, pc),
          ]),
        ]),
      );
    }).toList());
  }

  // ─── Payment Modal ───
  Widget _paymentModal(bool isDark, Color pc) {
    return GestureDetector(
      onTap: () => setState(() { _payingOrder = null; _selectedMethodId = null; }),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 400, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.gray800 : Colors.white,
              borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('选择支付方式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.gray900)),
              const SizedBox(height: 16),
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
                      border: Border.all(color: selected ? pc : (isDark ? AppColors.gray600 : AppColors.gray200), width: 2),
                      color: selected ? pc.withValues(alpha: 0.08) : Colors.transparent),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(method['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.gray900)),
                      if (selected) Icon(Icons.check_circle, size: 20, color: pc),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: SizedBox(height: 44, child: OutlinedButton(
                  onPressed: () => setState(() { _payingOrder = null; _selectedMethodId = null; }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.gray300 : AppColors.gray700,
                    side: BorderSide(color: isDark ? AppColors.gray600 : AppColors.gray300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('取消'),
                ))),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: 44, child: ElevatedButton(
                  onPressed: _processing ? null : _checkout,
                  style: ElevatedButton.styleFrom(backgroundColor: pc, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(_processing ? '处理中...' : '确认支付'),
                ))),
              ]),
            ]),
          ),
        )),
      ),
    );
  }

  Widget _statusBadge(int status, bool isDark) {
    Color bg, fg;
    switch (status) {
      case 0: bg = isDark ? const Color(0x4D92400E) : const Color(0xFFFEF3C7); fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      case 1: bg = isDark ? const Color(0x4D1E40AF) : const Color(0xFFDBEAFE); fg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      case 2: bg = isDark ? AppColors.gray700 : AppColors.gray100; fg = isDark ? AppColors.gray400 : AppColors.gray700;
      case 3: bg = isDark ? const Color(0x4D166534) : const Color(0xFFDCFCE7); fg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
      default: bg = AppColors.gray100; fg = AppColors.gray700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(_statusLabels[status] ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
    );
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.gray800 : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );
}
