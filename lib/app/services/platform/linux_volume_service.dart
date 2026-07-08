import 'dart:io';
import 'package:get/get.dart';
import '../app_logger.dart';
import '../storage_service.dart';

const _tag = 'LinuxVolumeService';

enum _AudioTool { pactl, wpctl, amixer }

/// Volume + output device control — Linux only.
/// Prefers pactl/wpctl (PulseAudio/PipeWire) so switching the selected
/// device actually changes the system default sink, not just a mixer
/// level on a specific ALSA card. Falls back to raw amixer if neither
/// is installed.
class LinuxVolumeService extends GetxService {
  _AudioTool? _tool;

  Future<_AudioTool> _detectTool() async {
    if (_tool != null) return _tool!;
    if (await _commandExists('pactl')) {
      _tool = _AudioTool.pactl;
    } else if (await _commandExists('wpctl')) {
      _tool = _AudioTool.wpctl;
    } else {
      _tool = _AudioTool.amixer;
    }
    return _tool!;
  }

  Future<bool> _commandExists(String cmd) async {
    try {
      final result = await Process.run('which', [cmd]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  List<String> _buildAmixerArgs(List<String> baseArgs) {
    try {
      final storage = Get.find<StorageService>();
      final cardIndex = storage.soundCardIndex;
      if (cardIndex != -1) {
        return ['-c', '$cardIndex', ...baseArgs];
      }
    } catch (e) {
      logger.d(_tag, 'StorageService not initialized yet: $e');
    }
    return baseArgs;
  }

  /// List available audio output devices (sinks) on the system.
  Future<List<Map<String, dynamic>>> getSoundCards() async {
    if (!Platform.isLinux) return [];
    final tool = await _detectTool();
    try {
      List<Map<String, dynamic>> cards;
      switch (tool) {
        case _AudioTool.pactl:
          cards = await _getSinksPactl();
          break;
        case _AudioTool.wpctl:
          cards = await _getSinksWpctl();
          break;
        case _AudioTool.amixer:
          cards = await _getCardsAmixer();
          break;
      }
      return cards
          .where((c) => !(c['desc'] as String).toUpperCase().contains('HDMI'))
          .toList();
    } catch (e, st) {
      logger.e(_tag, 'Error listing audio outputs', e, st);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSinksPactl() async {
    final defaultResult = await Process.run('pactl', ['get-default-sink']);
    final defaultName = defaultResult.stdout.toString().trim();

    final result = await Process.run('pactl', ['list', 'sinks']);
    final output = result.stdout.toString();
    final blocks = output.split(RegExp(r'(?=Sink #)'));
    final List<Map<String, dynamic>> sinks = [];
    for (final block in blocks) {
      final idMatch = RegExp(r'^Sink #(\d+)').firstMatch(block);
      if (idMatch == null) continue;
      final index = int.parse(idMatch.group(1)!);
      final nameMatch = RegExp(r'Name:\s*(.*)').firstMatch(block);
      final name = nameMatch?.group(1)?.trim() ?? '';
      final descMatch = RegExp(r'Description:\s*(.*)').firstMatch(block);
      final desc = descMatch?.group(1)?.trim().isNotEmpty == true
          ? descMatch!.group(1)!.trim()
          : name;
      sinks.add({
        'index': index,
        'desc': desc,
        'isDefault': name.isNotEmpty && name == defaultName,
      });
    }
    return sinks;
  }

  Future<List<Map<String, dynamic>>> _getSinksWpctl() async {
    final result = await Process.run('wpctl', ['status']);
    final output = result.stdout.toString();
    final startIdx = output.indexOf('Sinks:');
    if (startIdx == -1) return [];
    final afterSinks = output.substring(startIdx + 'Sinks:'.length);
    final endIdx = afterSinks.indexOf('Sink endpoints:');
    final section =
        endIdx == -1 ? afterSinks : afterSinks.substring(0, endIdx);

    final regex = RegExp(r'(\*?)\s*(\d+)\.\s+(.+?)\s*\[vol:');
    final List<Map<String, dynamic>> sinks = [];
    for (final line in section.split('\n')) {
      final match = regex.firstMatch(line);
      if (match == null) continue;
      final isDefault = match.group(1) == '*';
      final index = int.parse(match.group(2)!);
      final desc = match.group(3)!.trim();
      sinks.add({
        'index': index,
        'desc': desc,
        'isDefault': isDefault,
      });
    }
    return sinks;
  }

  Future<List<Map<String, dynamic>>> _getCardsAmixer() async {
    final file = File('/proc/asound/cards');
    if (!await file.exists()) return [];
    final storage = Get.find<StorageService>();
    final selected = storage.soundCardIndex;
    final lines = await file.readAsLines();
    final List<Map<String, dynamic>> cards = [];
    final regex = RegExp(r'^\s*(\d+)\s+\[([^\]]+)\]:\s+(.*)$');
    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final index = int.parse(match.group(1)!);
        final desc = match.group(3)!.trim();
        cards.add({
          'index': index,
          'desc': desc,
          'isDefault': index == selected,
        });
      }
    }
    return cards;
  }

  /// Switch the system default output device to [index].
  Future<void> setDefaultOutput(int index) async {
    if (!Platform.isLinux) return;
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          await Process.run('pactl', ['set-default-sink', '$index']);
          break;
        case _AudioTool.wpctl:
          await Process.run('wpctl', ['set-default', '$index']);
          break;
        case _AudioTool.amixer:
          // No system-level default to switch — amixer only scopes which
          // card's mixer subsequent get/set volume calls act on.
          break;
      }
    } catch (e, st) {
      logger.e(_tag, 'Set default output error', e, st);
    }
  }

  /// Get Master (output) volume and mute state
  Future<Map<String, dynamic>> getMasterVolume() async {
    if (!Platform.isLinux) return {'volume': 100, 'muted': false};
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          return await _getPactlVolume('sink');
        case _AudioTool.wpctl:
          return await _getWpctlVolume('@DEFAULT_AUDIO_SINK@');
        case _AudioTool.amixer:
          final result = await Process.run(
              'amixer', _buildAmixerArgs(['get', 'Master']));
          return _parseAmixerOutput(result.stdout.toString());
      }
    } catch (e, st) {
      logger.e(_tag, 'Get master volume error', e, st);
      return {'volume': 0, 'muted': false};
    }
  }

  /// Set Master (output) volume
  Future<void> setMasterVolume(int percent) async {
    if (!Platform.isLinux) return;
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          await Process.run(
              'pactl', ['set-sink-volume', '@DEFAULT_SINK@', '$percent%']);
          break;
        case _AudioTool.wpctl:
          await Process.run('wpctl',
              ['set-volume', '@DEFAULT_AUDIO_SINK@', '$percent%']);
          break;
        case _AudioTool.amixer:
          await Process.run('amixer',
              _buildAmixerArgs(['set', 'Master', '$percent%']));
          break;
      }
    } catch (e, st) {
      logger.e(_tag, 'Set master volume error', e, st);
    }
  }

  /// Get Capture (input) volume and mute state
  Future<Map<String, dynamic>> getCaptureVolume() async {
    if (!Platform.isLinux) return {'volume': 100, 'muted': false};
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          return await _getPactlVolume('source');
        case _AudioTool.wpctl:
          return await _getWpctlVolume('@DEFAULT_AUDIO_SOURCE@');
        case _AudioTool.amixer:
          final result = await Process.run(
              'amixer', _buildAmixerArgs(['get', 'Capture']));
          return _parseAmixerOutput(result.stdout.toString());
      }
    } catch (e, st) {
      logger.e(_tag, 'Get capture volume error', e, st);
      return {'volume': 0, 'muted': false};
    }
  }

  /// Set Capture (input) volume
  Future<void> setCaptureVolume(int percent) async {
    if (!Platform.isLinux) return;
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          await Process.run('pactl',
              ['set-source-volume', '@DEFAULT_SOURCE@', '$percent%']);
          break;
        case _AudioTool.wpctl:
          await Process.run('wpctl',
              ['set-volume', '@DEFAULT_AUDIO_SOURCE@', '$percent%']);
          break;
        case _AudioTool.amixer:
          await Process.run('amixer',
              _buildAmixerArgs(['set', 'Capture', '$percent%']));
          break;
      }
    } catch (e, st) {
      logger.e(_tag, 'Set capture volume error', e, st);
    }
  }

  /// Toggle Master (output) mute
  Future<void> toggleMasterMute() async {
    if (!Platform.isLinux) return;
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          await Process.run(
              'pactl', ['set-sink-mute', '@DEFAULT_SINK@', 'toggle']);
          break;
        case _AudioTool.wpctl:
          await Process.run(
              'wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle']);
          break;
        case _AudioTool.amixer:
          await Process.run(
              'amixer', _buildAmixerArgs(['set', 'Master', 'toggle']));
          break;
      }
    } catch (e, st) {
      logger.e(_tag, 'Toggle master mute error', e, st);
    }
  }

  /// Toggle Capture (input) mute
  Future<void> toggleCaptureMute() async {
    if (!Platform.isLinux) return;
    final tool = await _detectTool();
    try {
      switch (tool) {
        case _AudioTool.pactl:
          await Process.run(
              'pactl', ['set-source-mute', '@DEFAULT_SOURCE@', 'toggle']);
          break;
        case _AudioTool.wpctl:
          await Process.run(
              'wpctl', ['set-mute', '@DEFAULT_AUDIO_SOURCE@', 'toggle']);
          break;
        case _AudioTool.amixer:
          await Process.run(
              'amixer', _buildAmixerArgs(['set', 'Capture', 'toggle']));
          break;
      }
    } catch (e, st) {
      logger.e(_tag, 'Toggle capture mute error', e, st);
    }
  }

  Future<Map<String, dynamic>> _getPactlVolume(String kind) async {
    final target = '@DEFAULT_${kind.toUpperCase()}@';
    final volResult =
        await Process.run('pactl', ['get-$kind-volume', target]);
    final muteResult =
        await Process.run('pactl', ['get-$kind-mute', target]);
    final volumeMatch =
        RegExp(r'(\d+)%').firstMatch(volResult.stdout.toString());
    final volume = volumeMatch != null ? int.parse(volumeMatch.group(1)!) : 0;
    final muted = muteResult.stdout.toString().contains('yes');
    return {'volume': volume, 'muted': muted};
  }

  Future<Map<String, dynamic>> _getWpctlVolume(String target) async {
    final result = await Process.run('wpctl', ['get-volume', target]);
    final output = result.stdout.toString();
    final volumeMatch = RegExp(r'Volume:\s*([\d.]+)').firstMatch(output);
    final volume = volumeMatch != null
        ? (double.parse(volumeMatch.group(1)!) * 100).round()
        : 0;
    final muted = output.contains('[MUTED]');
    return {'volume': volume, 'muted': muted};
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
}
