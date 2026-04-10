import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel to control sing-box native process
/// Android: VpnService + libbox
/// iOS/macOS: NetworkExtension + libbox
/// Windows/Linux: sing-box binary process
class SingboxPlatformChannel {
  static const _channel = MethodChannel('com.xboard.singbox');
  static const _eventChannel = EventChannel('com.xboard.singbox/status');

  /// Start sing-box with the given config JSON
  Future<bool> start(String configJson) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'config': configJson,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SingboxPlatformChannel.start error: ${e.message}');
      return false;
    } on MissingPluginException {
      debugPrint('SingboxPlatformChannel: platform not implemented');
      return false;
    }
  }

  /// Stop sing-box
  Future<bool> stop() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stop');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('SingboxPlatformChannel.stop error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Check if sing-box is currently running
  Future<bool> isRunning() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Request VPN permission (Android only)
  Future<bool> requestVpnPermission() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true; // Non-Android platforms don't need explicit permission
    }
  }

  /// Listen to VPN status changes from the native side
  Stream<String> get statusStream {
    if (kIsWeb) return const Stream.empty();
    return _eventChannel.receiveBroadcastStream().map((event) {
      return event.toString();
    });
  }

  /// Write config file to platform-specific location
  Future<String?> writeConfig(String configJson) async {
    if (kIsWeb) return null;
    try {
      final path = await _channel.invokeMethod<String>('writeConfig', {
        'config': configJson,
      });
      return path;
    } on PlatformException catch (e) {
      debugPrint('SingboxPlatformChannel.writeConfig error: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
