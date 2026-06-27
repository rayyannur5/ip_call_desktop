import 'dart:io';
import 'package:get/get.dart';
import '../storage_service.dart';

/// Volume control via amixer — Linux only
class LinuxVolumeService extends GetxService {
  List<String> _buildAmixerArgs(List<String> baseArgs) {
    try {
      final storage = Get.find<StorageService>();
      final cardIndex = storage.soundCardIndex;
      if (cardIndex != -1) {
        return ['-c', '$cardIndex', ...baseArgs];
      }
    } catch (e) {
      print('StorageService not initialized yet: $e');
    }
    return baseArgs;
  }

  /// List all available soundcards on the system
  Future<List<Map<String, dynamic>>> getSoundCards() async {
    if (!Platform.isLinux) return [];
    try {
      final file = File('/proc/asound/cards');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        final List<Map<String, dynamic>> cards = [];
        final regex = RegExp(r'^\s*(\d+)\s+\[([^\]]+)\]:\s+(.*)$');
        for (var line in lines) {
          final match = regex.firstMatch(line);
          if (match != null) {
            final index = int.parse(match.group(1)!);
            final id = match.group(2)!;
            final desc = match.group(3)!.trim();
            cards.add({
              'index': index,
              'id': id,
              'desc': desc,
            });
          }
        }
        return cards;
      }
    } catch (e) {
      print('Error listing soundcards: $e');
    }
    return [];
  }

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
      final result = await Process.run('amixer', _buildAmixerArgs(['get', 'Master']));
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
      await Process.run('amixer', _buildAmixerArgs(['set', 'Master', '$percent%']));
    } catch (e) {
      print('Set master volume error: $e');
    }
  }

  /// Get Capture volume and mute state
  Future<Map<String, dynamic>> getCaptureVolume() async {
    if (!Platform.isLinux) return {'volume': 100, 'muted': false};

    try {
      final result = await Process.run('amixer', _buildAmixerArgs(['get', 'Capture']));
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
      await Process.run('amixer', _buildAmixerArgs(['set', 'Capture', '$percent%']));
    } catch (e) {
      print('Set capture volume error: $e');
    }
  }

  /// Toggle Master mute
  Future<void> toggleMasterMute() async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('amixer', _buildAmixerArgs(['set', 'Master', 'toggle']));
    } catch (e) {
      print('Toggle master mute error: $e');
    }
  }

  /// Toggle Capture mute
  Future<void> toggleCaptureMute() async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('amixer', _buildAmixerArgs(['set', 'Capture', 'toggle']));
    } catch (e) {
      print('Toggle capture mute error: $e');
    }
  }
}
