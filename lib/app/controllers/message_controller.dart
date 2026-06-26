import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../services/mqtt_service.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import 'home_controller.dart';
import 'call_controller.dart';

/// Port of message logic from App.jsx (line 323-453)
class MessageController extends GetxController {
  final messages = <Map<String, dynamic>>[].obs;

  Timer? _speakInterval;
  int _indexInterval = 0;
  int _counterIndexInterval = 0;

  @override
  void onInit() {
    super.onInit();

    // Register MQTT handlers
    final mqtt = Get.find<MqttService>();
    mqtt.addMessageHandler(_handleMqttMessage);

    // Restore state
    _restoreState();
  }

  void _restoreState() {
    try {
      final storage = Get.find<StorageService>();
      final state = storage.appState;
      if (state != null) {
        final decoded = jsonDecode(state);
        if (decoded['messages'] != null) {
          messages.value =
              List<Map<String, dynamic>>.from(decoded['messages']);
        }
      }
    } catch (_) {}
  }

  void _saveState() {
    try {
      final storage = Get.find<StorageService>();
      final callCtrl = Get.find<CallController>();
      storage.appState = jsonEncode({
        'calls': callCtrl.calls.toList(),
        'messages': messages.toList(),
      });
    } catch (_) {}
  }

  /// Handle MQTT messages — exact port of App.jsx constructor message handler
  void _handleMqttMessage(String topic, String message) {
    if (topic.contains('toilet')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'darurat');
      } else if (message == 'e') {
        addMessage(topic, message, '');
      }
    }

    if (topic.contains('bed')) {
      final id = topic.substring(4);
      _handleBedMessage(id, topic, message);
    }

    if (topic.contains('infus')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'infus');
      } else if (message == 'i') {
        addMessage(topic, message, '');
      }
    }

    if (topic.contains('blue')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'blue');
      } else if (message == 'b') {
        addMessage(topic, message, '');
      }
    }

    if (topic.contains('assist')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'assist');
      } else if (message == 'a') {
        addMessage(topic, message, '');
      }
    }

    if (topic.contains('tidakterjawab')) {
      if (message == 'x') {
        deleteMessage(topic, message, '');
      }
    }

    if (topic.contains('room')) {
      if (message == 'e') {
        addMessage(topic, message, '');
      } else if (message == 'c') {
        deleteMessage(topic, message, 'darurat');
      }
    }
  }

  /// Handle bed message with mode check — from App.jsx line 94-109
  Future<void> _handleBedMessage(
      String id, String topic, String message) async {
    try {
      final db = Get.find<DatabaseService>();
      final bed = await db.getBedById(id);
      if (bed == null) return;
      final mode = bed['mode'];

      if (message == 'c' || message == 'x') {
        if (mode == '2') {
          deleteMessage(topic, message, 'blue');
        } else {
          deleteMessage(topic, message, 'darurat');
        }
      } else if (message == 'e') {
        String msgCode = message;
        if (mode == '2') msgCode = 'b';
        addMessage(topic, msgCode, '');
      }
    } catch (e) {
      print('Handle bed message error: $e');
    }
  }

  /// Add message — port of App.jsx addMessage() (line 323-359)
  Future<void> addMessage(
      String topic, String message, String name) async {
    bool exist = messages.any((msg) => msg['topic'] == topic);
    if (exist) return;

    print('ADD MESSAGE : $topic : $message : $name');

    String resolvedName = name;
    if (name.isEmpty) {
      try {
        final db = Get.find<DatabaseService>();
        if (topic.contains('toilet')) {
          final id = topic.substring(7);
          final toilet = await db.getToiletById(id);
          resolvedName = toilet?['username'] ?? '';
        } else if (topic.contains('room')) {
          final parts = topic.split('_');
          final room = await db.getRoomById(parts[0]);
          resolvedName = 'Ruang ${room?['name'] ?? ''}';
        } else {
          final id = topic.substring(topic.length - 6);
          final bed = await db.getBedById(id);
          resolvedName = bed?['username'] ?? '';
        }
      } catch (e) {
        print('Resolve name error: $e');
      }
    }

    messages.add({
      'topic': topic,
      'created_at': DateTime.now().toIso8601String(),
      'message': message,
      'username': resolvedName,
    });
    _saveState();
    _newMessage();
  }

  /// Delete message — port of App.jsx deleteMessage() (line 362-389)
  void deleteMessage(String topic, String message, String type) {
    final msgIndex = messages.indexWhere((msg) => msg['topic'] == topic);
    if (msgIndex == -1) return;

    final msg = messages[msgIndex];
    final seconds = DateTime.now()
        .difference(DateTime.parse(msg['created_at']))
        .inSeconds
        .abs();

    messages.removeAt(msgIndex);

    if (type.isEmpty) {
      final home = Get.find<HomeController>();
      home.logKey.value++;
      _saveState();
      _newMessage();
      return;
    }

    // Create log entry
    final db = Get.find<DatabaseService>();
    final deviceId = topic.substring(topic.length - 6);
    final nursePresence = message == 'c' ? 1 : 0;
    db.createLog(type, deviceId, seconds, nursePresence).then((_) {
      final home = Get.find<HomeController>();
      home.logKey.value++;
      _saveState();
      _newMessage();
    });
  }

  /// Get category for message — port of App.jsx getCategoryMessage()
  String getCategoryMessage(int index) {
    if (index >= messages.length) return '';
    final msg = messages[index]['message'];
    switch (msg) {
      case 'e':
        return 'darurat';
      case 'w':
        return 'telepon';
      case 'b':
        return 'blue';
      case '0':
        return 'tidak_terjawab';
      case 'a':
        return 'perawat';
      default:
        return 'infus';
    }
  }

  /// Speak interval logic — port of App.jsx newMessage() (line 409-453)
  void _newMessage() {
    final audio = Get.find<AudioService>();

    if (messages.isNotEmpty) {
      if (_speakInterval == null) {
        print('SPEAK');

        try {
          final callCtrl = Get.find<CallController>();
          if (!callCtrl.onSession.value) {
            audio.speak(
              '${getCategoryMessage(0)} ${messages[0]['username']}',
              messages[_indexInterval]['message'],
              messages[_indexInterval]['username'],
            );
          }
        } catch (e) {
          print(e);
          _indexInterval = 0;
          _counterIndexInterval = 0;
        }

        final home = Get.find<HomeController>();
        _speakInterval = Timer.periodic(
          Duration(milliseconds: home.intervalSpeaks),
          (_) {
            _counterIndexInterval++;
            if (_counterIndexInterval == 3) {
              _counterIndexInterval = 0;
              _indexInterval++;
              if (_indexInterval >= messages.length) {
                _indexInterval = 0;
              }
            }

            if (_indexInterval >= messages.length) {
              _indexInterval = 0;
              _counterIndexInterval = 0;
            }

            try {
              final callCtrl = Get.find<CallController>();
              if (!callCtrl.onSession.value) {
                audio.speak(
                  '${getCategoryMessage(_indexInterval)} ${messages[_indexInterval]['username']}',
                  messages[_indexInterval]['message'],
                  messages[_indexInterval]['username'],
                );
              }
            } catch (e) {
              print(e);
              _indexInterval = 0;
              _counterIndexInterval = 0;
            }
          },
        );
      }
    } else {
      _speakInterval?.cancel();
      _speakInterval = null;
    }
  }

  @override
  void onClose() {
    _speakInterval?.cancel();
    Get.find<MqttService>().removeMessageHandler(_handleMqttMessage);
    super.onClose();
  }
}
