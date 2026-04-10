import 'dart:convert';
import 'package:xboard_client/core/constants/app_constants.dart';

/// Builds a sing-box configuration JSON with Clash API enabled
class SingboxConfigBuilder {
  /// Takes the raw sing-box config from the server subscription
  /// and injects the experimental.clash_api section for local control.
  static String injectClashApi(String rawConfig) {
    try {
      final config = jsonDecode(rawConfig) as Map<String, dynamic>;

      // Inject or override experimental.clash_api
      final experimental =
          (config['experimental'] as Map<String, dynamic>?) ?? {};
      experimental['clash_api'] = {
        'external_controller':
            '${AppConstants.clashApiHost}:${AppConstants.clashApiPort}',
        'default_mode': 'rule',
      };
      config['experimental'] = experimental;

      // Ensure inbound has mixed port for local proxy
      final inbounds = (config['inbounds'] as List<dynamic>?) ?? [];
      final hasMixed =
          inbounds.any((i) => i is Map && i['type'] == 'mixed');
      if (!hasMixed) {
        inbounds.add({
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': AppConstants.mixedPort,
        });
        config['inbounds'] = inbounds;
      }

      return jsonEncode(config);
    } catch (_) {
      // If parsing fails, return as-is and let sing-box handle it
      return rawConfig;
    }
  }
}
