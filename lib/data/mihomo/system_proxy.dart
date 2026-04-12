import 'dart:io';
import 'package:flutter/foundation.dart';

/// Sets / restores the OS-level HTTP proxy on Windows and macOS.
///
/// Windows: writes to the Internet Settings registry keys.
/// macOS:   uses `networksetup` against all hardware network services.
class SystemProxy {
  SystemProxy._();

  /// Enable the system proxy pointing to 127.0.0.1:[port].
  static Future<void> enable(int port) async {
    final host = '127.0.0.1';
    if (Platform.isWindows) {
      await _winSet(host, port, true);
    } else if (Platform.isMacOS) {
      await _macSet(host, port, true);
    }
    debugPrint('[SystemProxy] enabled → $host:$port');
  }

  /// Disable (restore) the system proxy.
  static Future<void> disable() async {
    if (Platform.isWindows) {
      await _winSet('', 0, false);
    } else if (Platform.isMacOS) {
      await _macSet('', 0, false);
    }
    debugPrint('[SystemProxy] disabled');
  }

  // ─── Windows ───

  static const _regPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static Future<void> _winSet(String host, int port, bool on) async {
    if (on) {
      await Process.run('reg', [
        'add', _regPath, '/v', 'ProxyEnable', '/t', 'REG_DWORD',
        '/d', '1', '/f',
      ]);
      await Process.run('reg', [
        'add', _regPath, '/v', 'ProxyServer', '/t', 'REG_SZ',
        '/d', '$host:$port', '/f',
      ]);
      // Bypass local addresses
      await Process.run('reg', [
        'add', _regPath, '/v', 'ProxyOverride', '/t', 'REG_SZ',
        '/d', 'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>',
        '/f',
      ]);
    } else {
      await Process.run('reg', [
        'add', _regPath, '/v', 'ProxyEnable', '/t', 'REG_DWORD',
        '/d', '0', '/f',
      ]);
    }
    // Notify the system that Internet Settings have changed.
    // This makes browsers pick up the new proxy immediately.
    await Process.run('powershell', [
      '-Command',
      r"[System.Runtime.InteropServices.RuntimeEnvironment]::FromGlobalAccessCache; "
      r'$signature = @"'
      '\n[DllImport("wininet.dll", SetLastError=true)]\n'
      r'public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
      '\n"@\n'
      r'$type = Add-Type -MemberDefinition $signature -Name WinInet -Namespace Pinvoke -PassThru;'
      r'$type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0);'
      r'$type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0);',
    ]);
  }

  // ─── macOS ───

  static Future<List<String>> _macServices() async {
    final result = await Process.run('networksetup', ['-listallhardwareports']);
    final lines = (result.stdout as String).split('\n');
    final services = <String>[];
    for (final line in lines) {
      if (line.startsWith('Hardware Port: ')) {
        services.add(line.substring('Hardware Port: '.length).trim());
      }
    }
    return services;
  }

  static Future<void> _macSet(String host, int port, bool on) async {
    final services = await _macServices();
    for (final svc in services) {
      if (on) {
        await Process.run('networksetup', ['-setwebproxy', svc, host, '$port']);
        await Process.run('networksetup', ['-setsecurewebproxy', svc, host, '$port']);
        await Process.run('networksetup', ['-setsocksfirewallproxy', svc, host, '$port']);
        await Process.run('networksetup', ['-setproxybypassdomains', svc,
            'localhost', '127.0.0.1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']);
      } else {
        await Process.run('networksetup', ['-setwebproxystate', svc, 'off']);
        await Process.run('networksetup', ['-setsecurewebproxystate', svc, 'off']);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', svc, 'off']);
      }
    }
  }
}
