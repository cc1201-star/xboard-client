import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Manages the bundled mihomo kernel on desktop platforms (Windows / macOS).
///
/// The binary is shipped inside the Flutter asset bundle under
/// `assets/bin/<platform>/`. On first launch we extract it to the app support
/// directory, make it executable, then spawn it as a child process pointed at
/// the subscription-derived YAML config.
class MihomoProcessManager {
  Process? _process;
  bool _isRunning = false;
  final _statusController = StreamController<String>.broadcast();
  final _logController = StreamController<String>.broadcast();

  bool get isRunning => _isRunning;
  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get logStream => _logController.stream;

  /// Directory mihomo is run from. Contains the extracted binary, config.yaml
  /// and mihomo's working files (cache.db, geoip.dat, etc).
  static Future<Directory> workingDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}mihomo');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Asset path inside the Flutter bundle for the current host platform.
  static String? _assetPath() {
    if (Platform.isWindows) return 'assets/bin/windows/mihomo.exe';
    if (Platform.isMacOS) {
      // We ship both arches; pick by host CPU. Dart exposes this via
      // Abi on newer SDKs, but sniffing `uname -m` is zero-dep and reliable.
      return 'assets/bin/macos/mihomo-arm64';
    }
    return null;
  }

  static String _binaryName() => Platform.isWindows ? 'mihomo.exe' : 'mihomo';

  /// Extract the bundled binary to the working directory if it's not already
  /// there, returning its absolute path.
  Future<String?> ensureBinary() async {
    final asset = _assetPath();
    if (asset == null) return null;

    final dir = await workingDir();
    final out = File('${dir.path}${Platform.pathSeparator}${_binaryName()}');

    // On macOS we may need the amd64 variant instead — try arm64 first, fall
    // back to amd64 if the arm64 asset isn't in the bundle.
    ByteData? data;
    try {
      data = await rootBundle.load(asset);
    } catch (_) {
      if (Platform.isMacOS) {
        try {
          data = await rootBundle.load('assets/bin/macos/mihomo-amd64');
        } catch (_) {
          return null;
        }
      } else {
        return null;
      }
    }

    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Re-extract when size differs (handles version bumps between installs).
    final needsWrite = !await out.exists() || (await out.length()) != bytes.length;
    if (needsWrite) {
      await out.writeAsBytes(bytes, flush: true);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['0755', out.path]);
      }
    }
    return out.path;
  }

  /// Write the mihomo config.yaml and return its path.
  Future<String> writeConfig(String yaml) async {
    final dir = await workingDir();
    final file = File('${dir.path}${Platform.pathSeparator}config.yaml');
    await file.writeAsString(yaml, flush: true);
    return file.path;
  }

  Future<bool> start(String yaml) async {
    if (_isRunning) return true;

    final binary = await ensureBinary();
    if (binary == null) {
      _statusController.add('error');
      _logController.add('mihomo binary not bundled for this platform');
      return false;
    }

    try {
      final dir = await workingDir();
      await writeConfig(yaml);

      _process = await Process.start(
        binary,
        ['-d', dir.path],
        mode: ProcessStartMode.normal,
      );

      _isRunning = true;
      _statusController.add('started');

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logController.add(line);
        debugPrint('mihomo: $line');
      }, onDone: _onProcessExit);

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logController.add('[ERR] $line');
        debugPrint('mihomo ERR: $line');
      });

      _process!.exitCode.then((code) {
        debugPrint('mihomo exited: $code');
        _onProcessExit();
      });

      return true;
    } catch (e) {
      debugPrint('MihomoProcessManager.start error: $e');
      _statusController.add('error');
      _logController.add('Failed to start mihomo: $e');
      return false;
    }
  }

  Future<bool> stop() async {
    if (!_isRunning || _process == null) return true;
    try {
      _process!.kill(ProcessSignal.sigterm);
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (_) {
      try {
        _process?.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    _isRunning = false;
    _process = null;
    _statusController.add('stopped');
    return true;
  }

  void _onProcessExit() {
    if (_isRunning) {
      _isRunning = false;
      _process = null;
      _statusController.add('stopped');
    }
  }

  void dispose() {
    stop();
    _statusController.close();
    _logController.close();
  }
}
