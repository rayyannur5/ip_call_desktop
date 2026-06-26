import 'dart:io';
import 'package:get/get.dart';

/// Volume control via amixer — Linux only
class LinuxVolumeService extends GetxService {
  /// Parse amixer output to get volume and mute state
  Map<String, dynamic> _parseAmixerOutput(String output) {
    int volume = 0;
    bool muted = false;

    final volumeMatch = RegExp(r'\[(\d+)%\]').firstMatch(output);
    if (volumeMatch != null) {
      volume = int.parse(volumeMatch.group(1)!);
    }

    final muteMatch = RegExp(r'\[(on|off)\]').firstMatch(output);
    if (muteMatch != null) {
      muted = muteMatch.group(1) == 'off';
    }

    return {'volume': volume, 'muted': muted};
  }

  /// Get Master volume and mute state
  Future<Map<String, dynamic>> getMasterVolume() async {
    if (!Platform.isLinux) return {'volume': 100, 'muted': false};

    try {
      final result = await Process.run('amixer', ['get', 'Master']);
      return _parseAmixerOutput(result.stdout.toString());
    } catch (e) {
      print('Get master volume error: $e');
      return {'volume': 0, 'muted': false};
    }
  }

  /// Set Master volume
  Future<void> setMasterVolume(int percent) async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('amixer', ['set', 'Master', '$percent%']);
    } catch (e) {
      print('Set master volume error: $e');
    }
  }

  /// Get Capture volume and mute state
  Future<Map<String, dynamic>> getCaptureVolume() async {
    if (!Platform.isLinux) return {'volume': 100, 'muted': false};

    try {
      final result = await Process.run('amixer', ['get', 'Capture']);
      return _parseAmixerOutput(result.stdout.toString());
    } catch (e) {
      print('Get capture volume error: $e');
      return {'volume': 0, 'muted': false};
    }
  }

  /// Set Capture volume
  Future<void> setCaptureVolume(int percent) async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('amixer', ['set', 'Capture', '$percent%']);
    } catch (e) {
      print('Set capture volume error: $e');
    }
  }

  /// Toggle Master mute
  Future<void> toggleMasterMute() async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('amixer', ['set', 'Master', 'toggle']);
    } catch (e) {
      print('Toggle master mute error: $e');
    }
  }

  /// Toggle Capture mute
  Future<void> toggleCaptureMute() async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('amixer', ['set', 'Capture', 'toggle']);
    } catch (e) {
      print('Toggle capture mute error: $e');
    }
  }
}
