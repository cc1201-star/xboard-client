class TrafficFormatter {
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  static String formatSpeed(int bytesPerSecond) {
    return '${formatBytes(bytesPerSecond)}/s';
  }

  static double usagePercent(int used, int total) {
    if (total <= 0) return 0;
    return (used / total).clamp(0.0, 1.0);
  }

  /// Parse subscription-userinfo header
  /// Format: "upload=123; download=456; total=789; expire=1234567890"
  static Map<String, int> parseSubscriptionUserinfo(String header) {
    final result = <String, int>{};
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        result[kv[0].trim()] = int.tryParse(kv[1].trim()) ?? 0;
      }
    }
    return result;
  }
}
