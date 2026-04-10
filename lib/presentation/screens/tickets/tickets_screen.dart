import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});
  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  bool _showForm = false;
  bool _submitting = false;
  // Form
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _level = 0;
  // Detail view
  Map<String, dynamic>? _viewingTicket;
  final _replyCtrl = TextEditingController();
  bool _sending = false;
  bool _closing = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _replyCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getTickets();
      setState(() { _tickets = resp.data['data'] as List? ?? []; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectCtrl.text.isEmpty || _messageCtrl.text.isEmpty) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() => _submitting = true);
    try {
      await client.saveTicket(_subjectCtrl.text, _level, _messageCtrl.text);
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() { _showForm = false; _submitting = false; _level = 0; });
      await _fetchTickets();
    } catch (_) {
      setState(() => _submitting = false);
    }
  }

  Future<void> _replyTicket() async {
    if (_replyCtrl.text.isEmpty || _viewingTicket == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() => _sending = true);
    try {
      await client.replyTicket(_viewingTicket!['id'] as int, _replyCtrl.text);
      _replyCtrl.clear();
      await _fetchTickets();
      // Update viewing ticket
      final updated = _tickets.firstWhere((t) => t['id'] == _viewingTicket!['id'], orElse: () => null);
      if (updated != null) {
        setState(() => _viewingTicket = updated as Map<String, dynamic>);
        _scrollToBottom();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _closeTicket() async {
    if (_viewingTicket == null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? AppColors.gray800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('确定要关闭此工单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('确定', style: TextStyle(color: Colors.white))),
        ],
      );
    });
    if (confirmed != true) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;
    setState(() => _closing = true);
    try {
      await client.closeTicket(_viewingTicket!['id'] as int);
      await _fetchTickets();
      final updated = _tickets.firstWhere((t) => t['id'] == _viewingTicket!['id'], orElse: () => null);
      if (updated != null) setState(() => _viewingTicket = updated as Map<String, dynamic>);
    } catch (_) {}
    if (mounted) setState(() => _closing = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static const _levelLabels = {0: '低', 1: '中', 2: '高'};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Center(child: SizedBox(width: 32, height: 32,
        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)));
    }

    // Detail view
    if (_viewingTicket != null) return _buildDetailView(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('工单', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.gray900)),
          ElevatedButton(
            onPressed: () => setState(() => _showForm = !_showForm),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('新建工单'),
          ),
        ]),
        const SizedBox(height: 24),

        // New ticket form
        if (_showForm) _buildForm(isDark),

        // Ticket list
        if (_tickets.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(48),
            decoration: _cardDeco(isDark),
            child: Text('暂无工单', textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray500)),
          )
        else ..._tickets.map((t) {
          final ticket = t as Map<String, dynamic>;
          final status = ticket['status'] as int? ?? 0;
          return GestureDetector(
            onTap: () => setState(() { _viewingTicket = ticket; _scrollToBottom(); }),
            child: Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20), decoration: _cardDeco(isDark),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(ticket['subject'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.gray900), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  _statusBadge(status, isDark),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text('优先级：${_levelLabels[ticket['level']] ?? '低'}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
                  const SizedBox(width: 12),
                  Text('最后回复：${_formatDate(ticket['updated_at'])}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray500)),
                ]),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('主题', isDark),
        const SizedBox(height: 4),
        TextField(controller: _subjectCtrl,
          decoration: InputDecoration(hintText: '请输入工单主题',
            filled: true, fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 16),
        _label('优先级', isDark),
        const SizedBox(height: 4),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: isDark ? AppColors.gray700 : AppColors.gray100,
            borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<int>(
            value: _level, isExpanded: true,
            dropdownColor: isDark ? AppColors.gray700 : Colors.white,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900),
            items: const [
              DropdownMenuItem(value: 0, child: Text('低')),
              DropdownMenuItem(value: 1, child: Text('中')),
              DropdownMenuItem(value: 2, child: Text('高')),
            ],
            onChanged: (v) => setState(() => _level = v ?? 0),
          )),
        ),
        const SizedBox(height: 16),
        _label('消息', isDark),
        const SizedBox(height: 4),
        TextField(controller: _messageCtrl, maxLines: 4,
          decoration: InputDecoration(hintText: '请描述您的问题...',
            filled: true, fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900)),
        const SizedBox(height: 16),
        SizedBox(height: 44, child: ElevatedButton(
          onPressed: _submitting ? null : _submitTicket,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_submitting ? '提交中...' : '提交工单'),
        )),
      ]),
    );
  }

  Widget _buildDetailView(bool isDark) {
    final ticket = _viewingTicket!;
    final status = ticket['status'] as int? ?? 0;
    final messages = ticket['message'] as List? ?? [];
    final isClosed = status == 1;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back link
        GestureDetector(
          onTap: () => setState(() => _viewingTicket = null),
          child: Text('← 返回工单列表', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
        ),
        const SizedBox(height: 8),
        // Title + close button
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ticket['subject'] ?? '', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.gray900)),
            const SizedBox(height: 4),
            _statusBadge(status, isDark),
          ])),
          if (!isClosed) OutlinedButton(
            onPressed: _closing ? null : _closeTicket,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_closing ? '关闭中...' : '关闭工单'),
          ),
        ]),
        const SizedBox(height: 24),

        // Messages
        Expanded(child: Container(
          padding: const EdgeInsets.all(24), decoration: _cardDeco(isDark),
          child: messages.isEmpty
            ? Center(child: Text('暂无消息', style: TextStyle(fontSize: 14, color: isDark ? AppColors.gray400 : AppColors.gray500)))
            : ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i] as Map<String, dynamic>;
                  final isMe = msg['is_me'] == true || msg['is_me'] == 1;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.gray700 : AppColors.gray100),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(msg['message'] ?? '', style: TextStyle(fontSize: 14,
                          color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.gray900))),
                        const SizedBox(height: 4),
                        Text(_formatDate(msg['created_at']), style: TextStyle(fontSize: 12,
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : (isDark ? AppColors.gray500 : AppColors.gray400))),
                      ]),
                    ),
                  );
                },
              ),
        )),

        // Reply form
        if (!isClosed) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16), decoration: _cardDeco(isDark),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: TextField(controller: _replyCtrl, maxLines: 3, minLines: 1,
                decoration: InputDecoration(hintText: '输入回复内容...',
                  filled: true, fillColor: isDark ? AppColors.gray700 : AppColors.gray100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.gray900))),
              const SizedBox(width: 12),
              SizedBox(height: 48, child: ElevatedButton(
                onPressed: _sending ? null : _replyTicket,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_sending ? '发送中...' : '发送'),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _statusBadge(int status, bool isDark) {
    final isOpen = status == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen
          ? (isDark ? const Color(0x4D166534) : const Color(0xFFDCFCE7))
          : (isDark ? AppColors.gray700 : AppColors.gray100),
        borderRadius: BorderRadius.circular(20)),
      child: Text(isOpen ? '开放' : '已关闭', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: isOpen
          ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
          : (isDark ? AppColors.gray400 : AppColors.gray600))),
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
      color: isDark ? AppColors.gray300 : AppColors.gray700));
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.gray800 : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
  );
}
