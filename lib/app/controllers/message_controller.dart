import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../services/mqtt_service.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/app_logger.dart';
import 'home_controller.dart';
import 'call_controller.dart';

const _tag = 'MessageController';

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
      final state = storage.appStateMessages;
      if (state != null && state.isNotEmpty) {
        final decoded = jsonDecode(state);
        messages.value = List<Map<String, dynamic>>.from(decoded);
      }
    } catch (_) {}
  }

  void _saveState() {
    try {
      final storage = Get.find<StorageService>();
      storage.appStateMessages = jsonEncode(messages.toList());
    } catch (_) {}
  }

  /// Handle MQTT messages — exact port of App.jsx constructor message handler
  void _handleMqttMessage(String topic, String message) {
    if (topic.startsWith('toilet/')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'darurat');
      } else if (message == 'e') {
        addMessage(topic, message, '');
      }
    }

    if (topic.startsWith('bed/')) {
      final id = topic.split('/').last;
      _handleBedMessage(id, topic, message);
    }

    if (topic.startsWith('infus/')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'infus');
      } else if (message == 'i') {
        addMessage(topic, message, '');
      }
    }

    if (topic.startsWith('blue/')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'blue');
      } else if (message == 'b') {
        addMessage(topic, message, '');
      }
    }

    if (topic.startsWith('assist/')) {
      if (message == 'c' || message == 'x') {
        deleteMessage(topic, message, 'assist');
      } else if (message == 'a') {
        addMessage(topic, message, '');
      }
    }

    if (topic.startsWith('tidakterjawab/')) {
      if (message == 'x') {
        deleteMessage(topic, message, '');
      }
    }

    if (topic.startsWith('room') || topic.contains('_room')) {
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
    } catch (e, st) {
      logger.e(_tag, 'Handle bed message error', e, st);
    }
  }

  /// Add message — port of App.jsx addMessage() (line 323-359)
  Future<void> addMessage(
      String topic, String message, String name) async {
    bool exist = messages.any((msg) => msg['topic'] == topic);
    if (exist) return;

    logger.d(_tag, 'Add message: $topic : $message : $name');

    String resolvedName = name;
    if (name.isEmpty) {
      try {
        final db = Get.find<DatabaseService>();
        if (topic.startsWith('toilet/')) {
          final id = topic.split('/').last;
          final toilet = await db.getToiletById(id);
          resolvedName = toilet?['username'] ?? '';
        } else if (topic.startsWith('room') || topic.contains('_room')) {
          final parts = topic.split('_');
          final room = await db.getRoomById(parts[0]);
          resolvedName = 'Ruang ${room?['name'] ?? ''}';
        } else {
          final id = topic.contains('/') ? topic.split('/').last : topic;
          final bed = await db.getBedById(id);
          resolvedName = bed?['username'] ?? '';
        }
      } catch (e, st) {
        logger.e(_tag, 'Resolve name error', e, st);
      }
    }

    final newMsg = {
      'topic': topic,
      'created_at': DateTime.now().toIso8601String(),
      'message': message,
      'username': resolvedName,
    };

    // Check toilet priority setting
    bool toiletPriority = false;
    try {
      toiletPriority = Get.find<HomeController>().toiletPriority.value;
    } catch (_) {}

    if (toiletPriority) {
      // If it's a toilet message, insert it after existing toilet messages but before other types of messages
      if (topic.startsWith('toilet/')) {
        int insertIndex = 0;
        for (int i = 0; i < messages.length; i++) {
          if (messages[i]['topic'].toString().startsWith('toilet/')) {
            insertIndex = i + 1;
          } else {
            break;
          }
        }
        messages.insert(insertIndex, newMsg);
      } else {
        // If not a toilet message, append it at the end of the list
        messages.add(newMsg);
      }
    } else {
      messages.add(newMsg);
    }

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
    final deviceId = topic.contains('/') ? topic.split('/').last : topic;
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

  void clearAllMessages() {
    messages.clear();
    _saveState();
    _newMessage();
  }

  /// Speak interval logic — port of App.jsx newMessage() (line 409-453)
  void _newMessage() {
    _speakInterval?.cancel();
    _speakInterval = null;

    _indexInterval = 0;
    _counterIndexInterval = 0;

    if (messages.isNotEmpty) {
      _doSpeak();
      final home = Get.find<HomeController>();
      _speakInterval = Timer.periodic(
        Duration(milliseconds: home.intervalSpeaks),
        (_) => _doSpeak(),
      );
    }
  }

  void _doSpeak() {
    if (messages.isEmpty) return;
    if (_indexInterval >= messages.length) {
      _indexInterval = 0;
      _counterIndexInterval = 0;
    }

    try {
      final audio = Get.find<AudioService>();
      final callCtrl = Get.find<CallController>();
      if (!callCtrl.onSession.value) {
        audio.speak(
          '${getCategoryMessage(_indexInterval)} ${messages[_indexInterval]['username']}',
          messages[_indexInterval]['message'],
          messages[_indexInterval]['username'],
        );
      }
    } catch (e, st) {
      logger.e(_tag, 'doSpeak error', e, st);
      _indexInterval = 0;
      _counterIndexInterval = 0;
    }

    _counterIndexInterval++;
    if (_counterIndexInterval >= 3) {
      _counterIndexInterval = 0;
      _indexInterval++;
      if (_indexInterval >= messages.length) {
        _indexInterval = 0;
      }
    }
  }

  @override
  void onClose() {
    _speakInterval?.cancel();
    Get.find<MqttService>().removeMessageHandler(_handleMqttMessage);
    super.onClose();
  }
}
