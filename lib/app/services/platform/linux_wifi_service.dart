import 'dart:io';
import 'package:get/get.dart';

/// WiFi management via nmcli — Linux only
class LinuxWifiService extends GetxService {
  /// Scan available WiFi networks
  Future<List<Map<String, String>>> scanWifi() async {
    if (!Platform.isLinux) return [];

    try {
      final result = await Process.run(
        'nmcli',
        ['-t', '-f', 'SSID,SIGNAL,SECURITY,IN-USE', 'device', 'wifi', 'list'],
      );

      final lines = result.stdout.toString().trim().split('\n');
      List<Map<String, String>> networks = [];

      for (final line in lines) {
        if (line.isEmpty) continue;
        final parts = line.split(':');
        if (parts.length >= 3) {
          networks.add({
            'ssid': parts[0],
            'signal': parts.length > 1 ? parts[1] : '',
            'security': parts.length > 2 ? parts[2] : '',
            'in_use': parts.length > 3 ? parts[3] : '',
          });
        }
      }

      return networks;
    } catch (e) {
      print('WiFi scan error: $e');
      return [];
    }
  }

  /// Connect to a WiFi network
  Future<bool> connectWifi(String ssid, String password) async {
    if (!Platform.isLinux) return false;

    try {
      final result = await Process.run(
        'nmcli',
        ['device', 'wifi', 'connect', ssid, 'password', password],
      );
      return result.exitCode == 0;
    } catch (e) {
      print('WiFi connect error: $e');
      return false;
    }
  }

  /// Get active connection name
  Future<String> getActiveConnection() async {
    if (!Platform.isLinux) return '';

    try {
      final result = await Process.run(
        'nmcli',
        ['-t', '-f', 'NAME,TYPE', 'connection', 'show', '--active'],
      );
      final lines = result.stdout.toString().trim().split('\n');
      for (final line in lines) {
        if (line.contains('wifi') || line.contains('wireless')) {
          return line.split(':').first;
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Disconnect from WiFi
  Future<bool> disconnect(String connectionName) async {
    if (!Platform.isLinux) return false;

    try {
      final result = await Process.run(
        'nmcli',
        ['connection', 'down', connectionName],
      );
      return result.exitCode == 0;
    } catch (e) {
      print('WiFi disconnect error: $e');
      return false;
    }
  }
}
