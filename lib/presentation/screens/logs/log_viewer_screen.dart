import 'package:xboard_client/presentation/widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/core/theme/app_theme.dart';
import 'package:xboard_client/presentation/providers/vpn_state_provider.dart';

class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  String _filterLevel = 'ALL';
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  LogEntry _parseLine(String line) {
    // Try to parse sing-box log format: "time level message"
    // e.g. "2024-01-01 12:00:01 INFO sing-box started"
    // or "[ERR] some error"
    String time = '';
    String level = 'INFO';
    String message = line;

    if (line.startsWith('[ERR]')) {
      level = 'ERROR';
      message = line.substring(5).trim();
    } else if (line.contains(' INFO ')) {
      final idx = line.indexOf(' INFO ');
      time = line.substring(0, idx).trim();
      level = 'INFO';
      message = line.substring(idx + 6).trim();
    } else if (line.contains(' WARN ') || line.contains(' warn ')) {
      final idx = line.indexOf(RegExp(r' [Ww][Aa][Rr][Nn] '));
      time = line.substring(0, idx).trim();
      level = 'WARN';
      message = line.substring(idx + 6).trim();
    } else if (line.contains(' ERROR ') || line.contains(' error ')) {
      final idx = line.indexOf(RegExp(r' [Ee][Rr][Rr][Oo][Rr] '));
      time = line.substring(0, idx).trim();
      level = 'ERROR';
      message = line.substring(idx + 7).trim();
    } else if (line.contains(' DEBUG ') || line.contains(' debug ')) {
      final idx = line.indexOf(RegExp(r' [Dd][Ee][Bb][Uu][Gg] '));
      time = line.substring(0, idx).trim();
      level = 'DEBUG';
      message = line.substring(idx + 7).trim();
    }

    if (time.isEmpty && line.length > 8) {
      // Try extracting time-like prefix
      final match = RegExp(r'^[\d\-T:\.]+\s').firstMatch(line);
      if (match != null) {
        time = match.group(0)!.trim();
        if (time.length > 8) time = time.substring(time.length - 8);
      }
    }

    return LogEntry(time: time, level: level, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final vpn = ref.watch(vpnStateProvider);
    final rawLogs = vpn.logs;
    final logs = rawLogs.map(_parseLine).toList();
    final filteredLogs = _filterLevel == 'ALL'
        ? logs
        : logs.where((l) => l.level == _filterLevel).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '日志',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.gray900,
                ),
              ),
              Row(
                children: [
                  ...['ALL', 'INFO', 'WARN', 'ERROR'].map((level) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _buildFilterChip(level, isDark),
                      )),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _exportLogs(rawLogs),
                    icon: Icon(Icons.file_download_outlined, color: AppColors.gray500, size: 20),
                    tooltip: '导出',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Log container
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.gray700 : AppColors.gray200),
                boxShadow: isDark
                    ? null
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        vpn.isConnected ? '暂无日志' : '连接 VPN 后将显示 sing-box 日志',
                        style: TextStyle(color: isDark ? AppColors.gray500 : AppColors.gray400),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (log.time.isNotEmpty)
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    log.time,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: isDark ? AppColors.gray500 : AppColors.gray400,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _levelBgColor(log.level),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.level,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _levelColor(log.level),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  log.message,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: isDark ? Colors.white : AppColors.gray900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String level, bool isDark) {
    final selected = _filterLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _filterLevel = level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)) : null,
        ),
        child: Text(
          level,
          style: TextStyle(
            color: selected ? Theme.of(context).colorScheme.primary : AppColors.gray400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    return switch (level) {
      'ERROR' => AppColors.error,
      'WARN' => AppColors.warning,
      'INFO' => AppColors.success,
      'DEBUG' => AppColors.info,
      _ => AppColors.gray500,
    };
  }

  Color _levelBgColor(String level) {
    return switch (level) {
      'ERROR' => AppColors.errorBg,
      'WARN' => AppColors.warningBg,
      'INFO' => AppColors.successBg,
      'DEBUG' => AppColors.infoBg,
      _ => AppColors.gray100,
    };
  }

  void _exportLogs(List<String> rawLogs) {
    final text = rawLogs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showTopToast(context, '日志已复制到剪贴板');
    }
  }
}

class LogEntry {
  final String time;
  final String level;
  final String message;

  LogEntry({required this.time, required this.level, required this.message});
}
