import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel bridge to the native mihomo runtime.
///   Android: VpnService + bundled mihomo binary under nativeLibraryDir.
///   iOS: not implemented in this build.
class MihomoPlatformChannel {
  static const _channel = MethodChannel('com.xboard.mihomo');
  static const _eventChannel = EventChannel('com.xboard.mihomo/status');

  Future<bool> start(String yaml) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'config': yaml,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('MihomoPlatformChannel.start error: ${e.message}');
      return false;
    } on MissingPluginException {
      debugPrint('MihomoPlatformChannel: platform not implemented');
      return false;
    }
  }

  Future<bool> stop() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stop');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('MihomoPlatformChannel.stop error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

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

  Future<bool> requestVpnPermission() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  Stream<String> get statusStream {
    if (kIsWeb) return const Stream.empty();
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }
}
