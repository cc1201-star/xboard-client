class AppConstants {
  static const String appName = 'Xboard';
  static const String appVersion = '1.0.0';

  /// Compile-time default server URL. Used as fallback when remote config and
  /// local cache are both unavailable.
  static const String defaultServerUrl = 'http://23.237.83.11:7001';

  /// URL of the remote config JSON file hosted on OSS/CDN.
  /// The JSON must contain: {"server_url": "https://your-panel.com"}
  /// Leave empty to disable remote config (will use defaultServerUrl).
  ///
  /// Examples:
  ///   Aliyun OSS:  https://your-bucket.oss-cn-hangzhou.aliyuncs.com/xboard/config.json
  ///   Tencent COS: https://your-bucket.cos.ap-guangzhou.myqcloud.com/xboard/config.json
  ///   Cloudflare:  https://your-r2.example.com/config.json
  ///   GitHub Raw:  https://raw.githubusercontent.com/you/repo/main/config.json
  static const String remoteConfigUrl = 'https://raw.githubusercontent.com/hfutchenchao-star/xboard-client/main/config.json';

  static const String mihomoVersion = '1.19.14';
  static const String mihomoFlag = 'meta';

  static const int clashApiPort = 9090;
  static const String clashApiHost = '127.0.0.1';
  static const int socksPort = 2333;
  static const int mixedPort = 2334;
  static const Duration subscribeRefreshInterval = Duration(hours: 24);
}
