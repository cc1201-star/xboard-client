import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/cache/screen_cache.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/data/api/xboard_api_client.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';
import 'package:xboard_client/presentation/widgets/skeleton.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});
  static Future<void> prefetch(XboardApiClient c) => _NoticesScreenState.prefetch(c);
  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  // 内存 + 磁盘双层缓存:首屏可能从磁盘秒读上次,后台再静默刷新
  static List<dynamic>? _cached = ScreenCache.readList('notices');
  List<dynamic> _notices = _cached ?? const [];
  bool _loading = _cached == null;
  int? _expandedId;

  /// 给 hover prefetch 用 — 不打开页面也能预热数据
  static Future<void> prefetch(XboardApiClient client) async {
    try {
      final resp = await client.getNotices();
      final data = resp.data['data'] as List? ?? [];
      _cached = data;
      await ScreenCache.writeList('notices', data);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    if (_cached == null) setState(() => _loading = true);
    try {
      final resp = await client.getNotices();
      final data = resp.data['data'] as List? ?? [];
      _cached = data;
      ScreenCache.writeList('notices', data);
      if (mounted) setState(() { _notices = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const TableRowsSkeleton(rows: 5);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('公告', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 24),

        if (_notices.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(48),
            decoration: _cardDeco(isDark),
            child: Text('暂无公告', textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray500)),
          )
        else ..._notices.map((n) {
          final notice = n as Map<String, dynamic>;
          final id = notice['id'] as int;
          final isExpanded = _expandedId == id;
          final content = notice['content'] as String? ?? '';
          final plainContent = _stripHtml(content);

          return Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
            decoration: _cardDeco(isDark),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              // Header (clickable)
              GestureDetector(
                onTap: () => setState(() => _expandedId = isExpanded ? null : id),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(notice['title'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.gray900)),
                      const SizedBox(height: 4),
                      Text(_formatDate(notice['created_at']),
                        style: TextStyle(fontSize: 12, color: AppColors.gray400)),
                      // Preview text
                      if (!isExpanded && plainContent.length > 200) ...[
                        const SizedBox(height: 12),
                        Text(plainContent.substring(0, 200), maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray300 : AppColors.gray600)),
                      ],
                    ])),
                    const SizedBox(width: 16),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, size: 20, color: AppColors.gray400),
                    ),
                  ]),
                ),
              ),
              // Expanded content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(border: Border(top: BorderSide(
                    color: isDark ? AppColors.gray700 : AppColors.gray100))),
                  child: SelectableText(plainContent,
                    style: TextStyle(fontSize: 14, height: 1.6,
                      color: isDark ? AppColors.gray300 : AppColors.gray700)),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.gray800 : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );
}
