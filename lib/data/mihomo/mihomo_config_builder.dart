import 'package:xboard_client/core/constants/app_constants.dart';

/// Injects runtime settings (clash API, mixed port, tun) into a mihomo YAML
/// subscription response without pulling in a full YAML library.
class MihomoConfigBuilder {
  /// Prepare the config for desktop (Windows/macOS) — enables the mixed inbound
  /// and Clash API external controller so the UI can drive it.
  static String prepareDesktop(String rawYaml) {
    var yaml = _stripBom(rawYaml);
    yaml = _upsertTopKey(yaml, 'mixed-port', '${AppConstants.mixedPort}');
    yaml = _upsertTopKey(yaml, 'allow-lan', 'false');
    yaml = _upsertTopKey(
      yaml,
      'external-controller',
      '${AppConstants.clashApiHost}:${AppConstants.clashApiPort}',
    );
    return yaml;
  }

  /// Prepare the config for Android — additionally enables the tun inbound
  /// which receives packets from the VpnService-managed file descriptor.
  /// The fd is passed through the `tun.file-descriptor` key.
  static String prepareAndroid(String rawYaml, int tunFd) {
    var yaml = prepareDesktop(rawYaml);
    yaml = _removeTopBlock(yaml, 'tun');
    final block = '''
tun:
  enable: true
  stack: system
  device: utun
  mtu: 9000
  auto-route: false
  auto-detect-interface: false
  file-descriptor: $tunFd
  dns-hijack:
    - any:53
''';
    return '$block\n$yaml';
  }

  /// Replace the top-level `key: value` line if present, otherwise prepend.
  /// Operates on the line that starts at column 0 to avoid touching nested
  /// keys under other maps.
  static String _upsertTopKey(String yaml, String key, String value) {
    final re = RegExp('^$key\\s*:.*\$', multiLine: true);
    if (re.hasMatch(yaml)) {
      return yaml.replaceFirst(re, '$key: $value');
    }
    return '$key: $value\n$yaml';
  }

  /// Remove a top-level block (e.g. `tun:` with its indented children) so we
  /// can prepend our own replacement. Only considers column-0 keys.
  static String _removeTopBlock(String yaml, String key) {
    final lines = yaml.split('\n');
    final out = <String>[];
    var skipping = false;
    final keyRe = RegExp('^$key\\s*:');
    final topLevelRe = RegExp(r'^\S');
    for (final line in lines) {
      if (skipping) {
        if (line.isEmpty) continue;
        if (topLevelRe.hasMatch(line)) {
          skipping = false;
          out.add(line);
        }
        continue;
      }
      if (keyRe.hasMatch(line)) {
        skipping = true;
        continue;
      }
      out.add(line);
    }
    return out.join('\n');
  }

  static String _stripBom(String s) =>
      s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF ? s.substring(1) : s;
}
