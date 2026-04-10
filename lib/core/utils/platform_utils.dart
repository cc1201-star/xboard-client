import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

bool get isWebPlatform => kIsWeb;

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

bool get isMobilePlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

bool get isVpnSupported {
  // VPN is supported on all native platforms, not on web
  return !kIsWeb;
}

String get currentPlatformName {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
