import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 给"页面级 dynamic 列表数据"做的轻量持久化层。
///
/// 设计点:
/// - 仅做内存 + 磁盘双层缓存,数据本身允许过期 / 失败 / 缺失(后台会刷新)。
/// - 不替代 SecureStorage(token / 敏感字段仍走那边)。
/// - 跨进程持久,杀掉 app 重开仍能秒显上次数据。
class ScreenCache {
  ScreenCache._();

  static SharedPreferences? _prefs;
  static const _prefix = 'screen_cache_v1.';

  /// 在 main() 里 runApp 之前调用一次。
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences? get _p => _prefs;

  /// 同步读取一个 dynamic List(已 jsonDecode 完)。
  /// 失败返回 null(没缓存或解析挂了)。
  static List<dynamic>? readList(String key) {
    final raw = _p?.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return null;
  }

  /// 异步写入。失败静默 ignore(磁盘问题不应阻塞主流程)。
  static Future<void> writeList(String key, List<dynamic> data) async {
    try {
      await _p?.setString('$_prefix$key', jsonEncode(data));
    } catch (_) {}
  }

  /// 清理某 key(比如登出时,如果你想彻底清掉)。
  static Future<void> remove(String key) async {
    await _p?.remove('$_prefix$key');
  }

  /// 清掉所有 screen_cache_ 开头的 key。
  static Future<void> clearAll() async {
    if (_p == null) return;
    final keys = _p!.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await _p!.remove(k);
    }
  }
}
