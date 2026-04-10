import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages sing-box as a subprocess on desktop platforms (Windows/macOS/Linux)
class SingboxProcessManager {
  Process? _process;
  bool _isRunning = false;
  final _statusController = StreamController<String>.broadcast();
  final _logController = StreamController<String>.broadcast();

  bool get isRunning => _isRunning;
  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get logStream => _logController.stream;

  /// Find the sing-box binary path
  /// Looks in order:
  /// 1. App data directory: {appData}/sing-box/sing-box(.exe)
  /// 2. Same directory as the executable
  /// 3. System PATH
  Future<String?> findBinary() async {
    final exeName = Platform.isWindows ? 'sing-box.exe' : 'sing-box';

    // 1. App data directory
    final appDir = await getApplicationSupportDirectory();
    final appBinary = File('${appDir.path}${Platform.pathSeparator}sing-box${Platform.pathSeparator}$exeName');
    if (await appBinary.exists()) return appBinary.path;

    // 2. Next to the executable
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final localBinary = File('$exeDir${Platform.pathSeparator}$exeName');
    if (await localBinary.exists()) return localBinary.path;

    // 3. System PATH
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [exeName],
      );
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim().split('\n').first.trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}

    return null;
  }

  /// Write config to a file and return the path
  Future<String> writeConfig(String configJson) async {
    final appDir = await getApplicationSupportDirectory();
    final configDir = Directory('${appDir.path}${Platform.pathSeparator}sing-box');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    final configFile = File('${configDir.path}${Platform.pathSeparator}config.json');
    await configFile.writeAsString(configJson);
    return configFile.path;
  }

  /// Start sing-box process with the given config
  Future<bool> start(String configJson) async {
    if (_isRunning) {
      debugPrint('SingboxProcessManager: already running');
      return true;
    }

    final binaryPath = await findBinary();
    if (binaryPath == null) {
      _statusController.add('error');
      _logController.add('sing-box binary not found. Please place sing-box executable in the app data directory.');
      return false;
    }

    try {
      final configPath = await writeConfig(configJson);

      _process = await Process.start(
        binaryPath,
        ['run', '-c', configPath],
        mode: ProcessStartMode.normal,
      );

      _isRunning = true;
      _statusController.add('started');

      // Monitor stdout
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          _logController.add(line);
          debugPrint('sing-box: $line');
        },
        onDone: () {
          _onProcessExit();
        },
      );

      // Monitor stderr
      _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          _logController.add('[ERR] $line');
          debugPrint('sing-box ERR: $line');
        },
      );

      // Monitor exit
      _process!.exitCode.then((code) {
        debugPrint('sing-box exited with code: $code');
        _onProcessExit();
      });

      return true;
    } catch (e) {
      debugPrint('SingboxProcessManager.start error: $e');
      _statusController.add('error');
      _logController.add('Failed to start sing-box: $e');
      return false;
    }
  }

  /// Stop sing-box process
  Future<bool> stop() async {
    if (!_isRunning || _process == null) return true;

    try {
      // Send SIGTERM (graceful shutdown)
      _process!.kill(ProcessSignal.sigterm);

      // Wait up to 5 seconds for graceful exit
      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Force kill if not responding
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      debugPrint('sing-box stopped with exit code: $exitCode');
      _isRunning = false;
      _process = null;
      _statusController.add('stopped');
      return true;
    } catch (e) {
      debugPrint('SingboxProcessManager.stop error: $e');
      // Force kill
      try {
        _process?.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _isRunning = false;
      _process = null;
      _statusController.add('stopped');
      return true;
    }
  }

  void _onProcessExit() {
    if (_isRunning) {
      _isRunning = false;
      _process = null;
      _statusController.add('stopped');
    }
  }

  /// Get the expected binary download URL for current platform
  static String getDownloadUrl(String version) {
    final arch = _getArch();
    final os = _getOs();
    final ext = Platform.isWindows ? '.zip' : '.tar.gz';
    return 'https://github.com/SagerNet/sing-box/releases/download/v$version/sing-box-$version-$os-$arch$ext';
  }

  /// Get the directory where sing-box binary should be placed
  static Future<String> getBinaryDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}${Platform.pathSeparator}sing-box';
  }

  static String _getOs() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String _getArch() {
    // Dart doesn't expose CPU architecture directly,
    // but on most desktop systems it's amd64
    // TODO: detect arm64 on Apple Silicon / Windows ARM
    return 'amd64';
  }

  void dispose() {
    stop();
    _statusController.close();
    _logController.close();
  }
}
