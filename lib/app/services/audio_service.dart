import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'mqtt_service.dart';
import 'database_service.dart';
import 'app_logger.dart';
import 'storage_service.dart';

const _tag = 'AudioService';

/// Port of speak.js — 100% same logic
class AudioService extends GetxService {
  final Map<String, String> _soundPaths = {};
  late AudioPlayer _ringingPlayer;
  late AudioPlayer _rejectedPlayer;
  late AudioPlayer _speakPlayer;

  bool _isRinging = false;
  bool _isSpeaking = false;
  static final _letterRegex = RegExp(r'^[a-zA-Z]$');

  void _recreateSpeakPlayer() {
    try {
      _speakPlayer.dispose();
    } catch (_) {}
    _speakPlayer = AudioPlayer();
  }

  void _recreateRingingPlayer() {
    try {
      _ringingPlayer.dispose();
    } catch (_) {}
    _ringingPlayer = AudioPlayer();
  }

  void _recreateRejectedPlayer() {
    try {
      _rejectedPlayer.dispose();
    } catch (_) {}
    _rejectedPlayer = AudioPlayer();
  }

  @override
  void onInit() {
    super.onInit();
    _ringingPlayer = AudioPlayer();
    _rejectedPlayer = AudioPlayer();
    _speakPlayer = AudioPlayer();
  }

  /// Initialize: load built-in sounds + dynamic sounds from DB
  Future<void> init() async {
    // Built-in speaks
    final speakFiles = [
      'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh',
      'delapan', 'sembilan', 'sepuluh', 'puluh', 'sebelas', 'belas',
      'darurat', 'telepon', 'infus', 'blue', 'tidak_terjawab', 'perawat',
    ];
    for (final name in speakFiles) {
      _soundPaths[name] = 'speaks/$name.ogg';
    }

    // Letter sounds A-L
    for (final letter in [
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'
    ]) {
      _soundPaths[letter] = 'speaks/${letter.toUpperCase()}.mp3';
    }

    // Try loading dynamic sounds from mastersound table
    await _loadDynamicSounds();
  }

  Future<void> _loadDynamicSounds() async {
    try {
      final db = Get.find<DatabaseService>();
      final storage = Get.find<StorageService>();
      final sounds = await db.getMasterSounds();

      final cacheDir = await getApplicationSupportDirectory();
      final soundCacheDir = Directory(p.join(cacheDir.path, 'sounds'));
      if (!await soundCacheDir.exists()) {
        await soundCacheDir.create(recursive: true);
      }

      for (final sound in sounds) {
        final name = (sound['name'] ?? '').toLowerCase();
        final source = sound['source'];
        if (name.isEmpty || source == null) continue;

        final localPath = p.join(soundCacheDir.path, p.basename(source));
        final localFile = File(localPath);

        // Download if not cached
        if (!await localFile.exists()) {
          try {
            final url = 'http://${storage.serverHost}/$source';
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await localFile.writeAsBytes(response.bodyBytes);
            }
          } catch (e, st) {
            logger.e(_tag, 'Failed to download sound $name', e, st);
          }
        }

        if (await localFile.exists()) {
          _soundPaths[name] = localPath;
        }
      }
    } catch (e, st) {
      logger.e(_tag, 'Failed to load dynamic sounds', e, st);
    }
  }

  /// Play a sound and wait until it finishes (port of playSound in speak.js)
  Future<void> _playSound(String key) async {
    final path = _soundPaths[key];
    if (path == null) return;

    final completer = Completer<void>();
    Timer? fallbackTimer;

    void onComplete() {
      fallbackTimer?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    final subscription = _speakPlayer.onPlayerComplete.listen((_) {
      onComplete();
    });

    // Fallback timeout
    fallbackTimer = Timer(const Duration(seconds: 3), () {
      onComplete();
    });

    try {
      // Determine if asset or file
      if (path.startsWith('/') || path.contains(':\\')) {
        final file = File(path);
        if (await file.exists()) {
          await _speakPlayer.play(DeviceFileSource(path));
        } else {
          logger.w(_tag, 'Sound file does not exist: $path');
          onComplete();
        }
      } else {
        await _speakPlayer.play(AssetSource(path));
      }
    } catch (e, st) {
      logger.e(_tag, 'Play sound failed, recreating AudioPlayer', e, st);
      _recreateSpeakPlayer();
      onComplete();
    }

    await completer.future;
    subscription.cancel();
  }

  /// Number to Indonesian text (port of numberToText in speak.js)
  String numberToText(int num) {
    String getText(int oneNum) {
      switch (oneNum) {
        case 0: return 'kosong';
        case 1: return 'satu';
        case 2: return 'dua';
        case 3: return 'tiga';
        case 4: return 'empat';
        case 5: return 'lima';
        case 6: return 'enam';
        case 7: return 'tujuh';
        case 8: return 'delapan';
        case 9: return 'sembilan';
        default: return '';
      }
    }

    final puluhan = num ~/ 10;
    final satuan = num % 10;

    if (num == 10) return 'sepuluh';
    if (num == 11) return 'sebelas';
    if (puluhan == 1 && satuan > 1) return '${getText(satuan)} belas';
    if (puluhan != 0 && satuan != 0) {
      return '${getText(puluhan)} puluh ${getText(satuan)}';
    }
    if (puluhan != 0 && satuan == 0) return '${getText(puluhan)} puluh';
    return getText(satuan);
  }

  bool _isLetter(String char) {
    return _letterRegex.hasMatch(char);
  }

  /// Port of speak() in speak.js — exact same logic
  Future<void> speak(String str, String msg, String username) async {
    if (_isSpeaking) {
      logger.d(_tag, 'Already speaking, skipping.');
      return;
    }
    _isSpeaking = true;
    try {
      final mqtt = Get.find<MqttService>();

      List<String> splitDot = username.split(' ');
      String fixDotStr;

      if (splitDot[0].toLowerCase() != 'toilet') {
        if (msg == 'e') {
          splitDot[0] = 'Darurat';
        } else if (msg == 'i') {
          splitDot[0] = 'Infus';
        } else if (msg == 'a') {
          splitDot[0] = 'Perawat';
        } else if (msg == 'b') {
          splitDot[0] = 'CodeBlue';
        }
        fixDotStr =
            '${splitDot[0]} ${splitDot.length > 1 ? splitDot[1] : ''} ${splitDot.length > 2 ? splitDot[2] : ''}';
      } else {
        fixDotStr = '${splitDot[0]} ${splitDot.length > 1 ? splitDot[1] : ''}';
      }

      await Future.delayed(const Duration(milliseconds: 300));
      mqtt.publish('dotmatrix', fixDotStr);

      final strArray = str.toLowerCase().split(' ');
      logger.d(_tag, 'Speak: $strArray');

      final lastIndex = strArray.length - 1;
      const wordGap = 100; // ms
      const numberGap = 50; // ms

      for (int i = 0; i < strArray.length; i++) {
        final word = strArray[i];
        final isLastWord = (i == lastIndex);

        if (_isLetter(word)) {
          await _playSound(word);
        } else if (isLastWord && int.tryParse(word) != null) {
          final strNumberArray = numberToText(int.parse(word)).split(' ');
          for (int j = 0; j < strNumberArray.length; j++) {
            final val = strNumberArray[j];
            await _playSound(val);
            if (j < strNumberArray.length - 1) {
              await Future.delayed(const Duration(milliseconds: numberGap));
            }
          }
        } else {
          await _playSound(word);
        }

        if (i < strArray.length - 1) {
          mqtt.publish('dotmatrix', fixDotStr);
          await Future.delayed(const Duration(milliseconds: wordGap));
        }
      }
    } catch (e, st) {
      logger.e(_tag, 'Speak error', e, st);
    } finally {
      _isSpeaking = false;
    }
  }

  // --- Ringing / Rejected ---

  Future<void> playRinging() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      await _ringingPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringingPlayer.play(AssetSource('sounds/ringing.ogg'));
    } catch (e, st) {
      logger.e(_tag, 'Play ringing failed, recreating AudioPlayer', e, st);
      _recreateRingingPlayer();
      try {
        await _ringingPlayer.setReleaseMode(ReleaseMode.loop);
        await _ringingPlayer.play(AssetSource('sounds/ringing.ogg'));
      } catch (_) {}
    }
  }

  void stopRinging() {
    _isRinging = false;
    try {
      _ringingPlayer.stop();
    } catch (_) {}
  }

  Future<void> playRejected() async {
    try {
      await _rejectedPlayer.play(AssetSource('sounds/rejected.mp3'));
    } catch (e, st) {
      logger.e(_tag, 'Play rejected failed, recreating AudioPlayer', e, st);
      _recreateRejectedPlayer();
      try {
        await _rejectedPlayer.play(AssetSource('sounds/rejected.mp3'));
      } catch (_) {}
    }
  }

  @override
  void onClose() {
    _ringingPlayer.dispose();
    _rejectedPlayer.dispose();
    _speakPlayer.dispose();
    super.onClose();
  }
}
