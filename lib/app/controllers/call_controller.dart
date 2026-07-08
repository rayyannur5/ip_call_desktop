import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../services/mqtt_service.dart';
import '../services/sip_service.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/app_logger.dart';
import 'home_controller.dart';
import 'message_controller.dart';

const _tag = 'CallController';

/// Port of call logic from App.jsx (line 247-520) + Telpon.jsx
class CallController extends GetxController {
  final calls = <Map<String, dynamic>>[].obs;
  final onSession = false.obs;
  final isAnswering = false.obs;

  Timer? _timeout;
  Timer? _timeoutSipError;
  Timer? _callTimer;

  /// Per-call elapsed seconds
  final callSeconds = <int>[].obs;

  void bindSipCallbacks() {
    final sip = Get.find<SipService>();
    sip.onCallAccepted = _onSipCallAccepted;
    sip.onCallEnded = _onSipCallEnded;
  }

  @override
  void onInit() {
    super.onInit();

    // Register MQTT handlers for call-related topics
    final mqtt = Get.find<MqttService>();
    mqtt.addMessageHandler(_handleMqttMessage);

    // Register SIP callbacks
    bindSipCallbacks();

    // Automatically manage callSeconds timer based on calls list
    ever(calls, (_) => _manageCallTimer());

    // Restore state
    _restoreState();

    _manageCallTimer();
  }

  void _manageCallTimer() {
    if (calls.isNotEmpty) {
      if (_callTimer == null) {
        _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _updateCallSeconds();
        });
      }
    } else {
      _callTimer?.cancel();
      _callTimer = null;
      callSeconds.clear();
    }
  }

  void _restoreState() {
    try {
      final storage = Get.find<StorageService>();
      final state = storage.appStateCalls;
      if (state != null && state.isNotEmpty) {
        final decoded = jsonDecode(state);
        calls.value = List<Map<String, dynamic>>.from(decoded);
      }
    } catch (_) {}
  }

  void _saveState() {
    try {
      final storage = Get.find<StorageService>();
      storage.appStateCalls = jsonEncode(calls.toList());
    } catch (_) {}
  }

  void _updateCallSeconds() {
    try {
      if (calls.isEmpty) {
        callSeconds.clear();
        return;
      }
      final home = Get.find<HomeController>();
      final timeoutLimitSec = home.timeoutCall ~/ 1000;
      
      List<int> newSeconds = [];
      List<Map<String, dynamic>> callsToTimeout = [];

      final currentCalls = List<Map<String, dynamic>>.from(calls);

      for (int i = 0; i < currentCalls.length; i++) {
        final call = currentCalls[i];
        int second = 0;

        if (call['created_at'] != null) {
          second = DateTime.now()
              .difference(DateTime.parse(call['created_at']))
              .inSeconds
              .abs();
        } else if (call['started_at'] != null) {
          second = DateTime.now()
              .difference(DateTime.parse(call['started_at']))
              .inSeconds
              .abs();
        }

        // Handle unanswered incoming call timeouts individually with re-entrancy guard
        if (call['type'] == 'incoming' && 
            call['created_at'] == null && 
            call['_timing_out'] != true && 
            second >= timeoutLimitSec) {
          call['_timing_out'] = true;
          callsToTimeout.add(call);
        }

        // Auto hangup active call at 600 seconds (from Telpon.jsx line 20-22)
        if (second > 600 && i == 0) {
          hangUp();
          return;
        }

        newSeconds.add(second);
      }

      callSeconds.assignAll(newSeconds);

      // Process timeout for any expired calls
      if (callsToTimeout.isNotEmpty) {
        for (final call in callsToTimeout) {
          _handleSingleCallTimeout(call);
        }
      }
    } catch (e, st) {
      logger.e(_tag, 'Error updating call seconds', e, st);
    }
  }

  Future<void> _handleSingleCallTimeout(Map<String, dynamic> call) async {
    final audio = Get.find<AudioService>();
    final topic = call['topic'];
    String id = topic;
    if (id.contains('/')) {
      id = id.split('/').last;
    }
    
    logger.d(_tag, 'Call timeout triggered for ID $id (elapsed >= DB timeout)');

    final isFirstCall = (calls.isNotEmpty && calls[0]['topic'] == topic);
    if (isFirstCall) {
      audio.stopRinging();
      audio.playRejected();
    }

    final messageCtrl = Get.find<MessageController>();
    messageCtrl.addMessage('tidakterjawab/$id', '0', call['name']);

    final mqtt = Get.find<MqttService>();
    mqtt.publish('tidakterjawab/$id', 'y', qos: MqttQos.atLeastOnce, retain: true);
    mqtt.publish('stop/$id', 's', qos: MqttQos.atLeastOnce, retain: true);
    mqtt.publish('call/$id', 'x', qos: MqttQos.atLeastOnce, retain: true);

    try {
      final db = Get.find<DatabaseService>();
      await db.createHistory(id, 2);
    } catch (e, st) {
      logger.e(_tag, 'History creation error on timeout', e, st);
    }

    logger.d(_tag, 'Removing call $topic from queue after history created.');
    final index = calls.indexWhere((c) => c['topic'] == topic);
    if (index != -1) {
      calls.removeAt(index);
      if (index == 0) {
        // If we removed the first call, clean up session state and trigger next
        onSession.value = false;
        if (calls.isNotEmpty) {
          calls[0] = {
            ...calls[0],
            'started_at': DateTime.now().toIso8601String(),
          };
        }
        _saveState();
        _newCall();
      } else {
        _saveState();
      }
    }
  }

  void _handleMqttMessage(String topic, String message) {
    // Handle incoming calls — from App.jsx line 131-165
    if (topic.startsWith('call/')) {
      if (message == '1') {
        bool exist = calls.any((c) => c['topic'] == topic);
        if (!exist) {
          final id = topic.substring(5);
          _handleIncomingCall(id, topic);
        }
      } else if (message == 'c' || message == 'x') {
        // Delegate to message controller for deleteMessage
        final messageCtrl = Get.find<MessageController>();
        messageCtrl.deleteMessage(topic, message, 'call');
      }
    }

    // Handle call answered confirmation — from App.jsx line 179-190
    if (topic == 'panggil' && message == '1') {
      final audio = Get.find<AudioService>();
      audio.stopRinging();
      logger.i(_tag, 'Call answered (dijawab)');
      _timeout?.cancel();
      _timeoutSipError?.cancel();

      if (calls.isNotEmpty) {
        calls[0] = {
          ...calls[0],
          'created_at': DateTime.now().toIso8601String(),
        };
        calls.refresh();
      }
      onSession.value = true;
      _saveState();
    }
  }

  Future<void> _handleIncomingCall(String id, String topic) async {
    try {
      final db = Get.find<DatabaseService>();
      final bed = await db.getBedById(id);
      if (bed == null) return;

      if (bed['mode'] == '1') {
        // Mode 1: add as message (not a call)
        final messageCtrl = Get.find<MessageController>();
        messageCtrl.addMessage(topic, 'q', bed['username'] ?? '');
      } else {
        // Mode 0/2: add as incoming call
        calls.add({
          'topic': topic,
          'name': bed['username'] ?? '',
          'created_at': null,
          'started_at': DateTime.now().toIso8601String(),
          'session': false,
          'state': 0,
          'type': 'incoming',
          'phone': bed['phone'] ?? '',
        });
        _saveState();
        _newCall();
      }
    } catch (e, st) {
      logger.e(_tag, 'Handle incoming call error', e, st);
    }
  }

  /// Initiate outgoing call — port of App.jsx call() (line 247-284)
  Future<void> call(String id, String number, String name) async {
    if (calls.isNotEmpty) return;
    logger.i(_tag, 'Outgoing call to $number ($name)');

    final mqtt = Get.find<MqttService>();
    final sip = Get.find<SipService>();
    final audio = Get.find<AudioService>();

    // SIP call (replaces mqtt.publish("panggil", number))
    sip.makeCall(number);
    mqtt.publish('call/$id', 'a', qos: MqttQos.atLeastOnce, retain: true);

    calls.assignAll([
      {
        'topic': 'call/$id',
        'name': name,
        'created_at': null,
        'state': 1,
        'type': 'outgoing',
        'phone': number,
      }
    ]);
    _saveState();

    // SIP error timeout (15s) — from App.jsx line 265-280
    _timeoutSipError?.cancel();
    _timeoutSipError = Timer(const Duration(seconds: 15), () {
      if (calls.isEmpty) return;
      mqtt.publish(calls[0]['topic'], 'x',
          qos: MqttQos.atLeastOnce, retain: true);
      sip.hangUp();
      audio.stopRinging();

      calls.removeAt(0);
      onSession.value = false;
      _saveState();

      // Show error dialog
      Get.defaultDialog(
        title: 'Panggilan Error',
        middleText: 'Device tidak menanggapi panggilan',
      );
      _timeout?.cancel();
      _timeoutSipError?.cancel();
    });

    _newCall();
  }

  /// Manage ringing and timeout — port of App.jsx newCall() (line 286-321)
  void _newCall() {
    logger.d(_tag, '_newCall() triggered. calls size: ${calls.length}, onSession: ${onSession.value}');
    final audio = Get.find<AudioService>();

    _updateCallSeconds();

    if (calls.isNotEmpty) {
      logger.d(_tag, 'Playing ringing. First call in queue: topic=${calls[0]['topic']}, created_at=${calls[0]['created_at']}');
      audio.playRinging();

      if (onSession.value) {
        logger.d(_tag, 'onSession is true, immediately stopping ringing.');
        audio.stopRinging();
      }
    } else {
      logger.d(_tag, 'calls is empty, stopping ringing.');
      audio.stopRinging();
    }
  }

  /// Hang up — port of App.jsx hangUp() (line 455-497)
  void hangUp() {
    logger.d(_tag, 'hangUp() called. Current calls size before remove: ${calls.length}');
    final mqtt = Get.find<MqttService>();
    final sip = Get.find<SipService>();
    final audio = Get.find<AudioService>();

    _timeout?.cancel();
    _timeoutSipError?.cancel();
    isAnswering.value = false;

    // SIP hangup (replaces mqtt.publish("tutup", "1"))
    sip.hangUp();
    audio.stopRinging();

    if (calls.isEmpty) {
      logger.d(_tag, 'hangUp() calls list is empty, aborting.');
      onSession.value = false;
      _saveState();
      return;
    }

    final activeCall = calls.removeAt(0);
    logger.d(_tag, 'Removed active call: topic=${activeCall['topic']}, name=${activeCall['name']}, created_at=${activeCall['created_at']}, type=${activeCall['type']}');

    try {
      final createdAt = activeCall['created_at'];
      int time = 0;
      if (createdAt != null) {
        time = DateTime.now()
            .difference(DateTime.parse(createdAt))
            .inSeconds
            .abs();
      }
      logger.i(_tag, 'Call ended. topic=${activeCall['topic']}, duration=${time}s');

      String id = activeCall['topic'];
      if (id.contains('/')) {
        id = id.split('/').last;
      }
      mqtt.publish('call/$id', 'h', qos: MqttQos.atLeastOnce, retain: true);

      if (activeCall['type'] == 'incoming') {
        mqtt.publish('stop/$id', 'm', qos: MqttQos.atLeastOnce, retain: true);
        final messageCtrl = Get.find<MessageController>();
        logger.d(_tag, 'activeCall is incoming, adding message ${activeCall['topic']} with code w');
        messageCtrl.addMessage(activeCall['topic'], 'w', activeCall['name']);
      }

      final db = Get.find<DatabaseService>();
      if (activeCall['type'] == 'incoming') {
        mqtt.publish('call/$id', 'l',
            qos: MqttQos.atLeastOnce, retain: true);
        db.createHistory(id, 1,
            duration: _getWaktuTerbilang(time));
      } else {
        db.createHistory(id, 3,
            duration: _getWaktuTerbilang(time));
      }
    } catch (e, st) {
      logger.e(_tag, 'Exception in hangUp() — treating as unanswered call', e, st);
      _timeout?.cancel();
      String id = activeCall['topic'];
      if (id.contains('/')) {
        id = id.split('/').last;
      }
      mqtt.publish('stop/$id', 's',
          qos: MqttQos.atLeastOnce, retain: true);
      mqtt.publish('call/$id', 'c',
          qos: MqttQos.atLeastOnce, retain: true);
    }

    logger.d(_tag, 'After hangUp processing. Remaining calls size: ${calls.length}');
    if (calls.isNotEmpty) {
      logger.d(_tag, 'Resetting started_at for new first call in queue: ${calls[0]['topic']}');
      // Reset started_at for the next call in queue so the timer starts from 0
      calls[0] = {
        ...calls[0],
        'started_at': DateTime.now().toIso8601String(),
      };
    }
    onSession.value = false;
    _saveState();
    _newCall();
  }

  /// Answer incoming call — port of App.jsx handlerAnswer() (line 499-520)
  void handlerAnswer(Map<String, dynamic> call) {
    if (isAnswering.value) {
      logger.d(_tag, 'Already answering call, ignoring duplicate answer request.');
      return;
    }
    isAnswering.value = true;

    final mqtt = Get.find<MqttService>();
    final sip = Get.find<SipService>();

    try {
      // SIP call (replaces mqtt.publish("panggil", call.phone))
      sip.makeCall(call['phone']);
      mqtt.publish(call['topic'], 'a', qos: MqttQos.atLeastOnce, retain: true);
    } catch (e, st) {
      logger.e(_tag, 'SIP call failed', e, st);
      isAnswering.value = false;
    }

    final audio = Get.find<AudioService>();
    _timeoutSipError?.cancel();
    _timeoutSipError = Timer(const Duration(seconds: 15), () {
      isAnswering.value = false;
      if (calls.isEmpty) return;
      mqtt.publish(calls[0]['topic'], 'x',
          qos: MqttQos.atLeastOnce, retain: true);
      sip.hangUp();
      audio.stopRinging();

      calls.removeAt(0);
      onSession.value = false;
      _saveState();

      Get.defaultDialog(
        title: 'Panggilan Error',
        middleText: 'Device tidak menanggapi panggilan',
      );
      _timeout?.cancel();
      _timeoutSipError?.cancel();
    });
  }

  void _onSipCallAccepted() {
    isAnswering.value = false;
    // SIP confirmed — same as MQTT "panggil" = "1"
    final audio = Get.find<AudioService>();
    audio.stopRinging();
    _timeout?.cancel();
    _timeoutSipError?.cancel();

    if (calls.isNotEmpty) {
      calls[0] = {
        ...calls[0],
        'created_at': DateTime.now().toIso8601String(),
      };
      calls.refresh();
    }
    onSession.value = true;
    _saveState();
  }

  void _onSipCallEnded() {
    // SIP call ended externally
    logger.d(_tag, '_onSipCallEnded() callback. onSession: ${onSession.value}, calls size: ${calls.length}');
    if (onSession.value && calls.isNotEmpty) {
      logger.d(_tag, 'onSession is true, triggering hangUp()');
      hangUp();
    } else {
      logger.d(_tag, 'onSession is false, ignoring SIP ended event for waiting call.');
    }
  }

  String _getWaktuTerbilang(int detikAwal) {
    final detik = detikAwal % 60;
    final menit = (detikAwal ~/ 60) % 60;
    final jam = detikAwal ~/ 3600;

    if (jam != 0) {
      return '$jam jam $menit menit $detik detik';
    } else if (menit != 0) {
      return '$menit menit $detik detik';
    } else {
      return '$detik detik';
    }
  }

  @override
  void onClose() {
    _timeout?.cancel();
    _timeoutSipError?.cancel();
    _callTimer?.cancel();
    Get.find<MqttService>().removeMessageHandler(_handleMqttMessage);
    super.onClose();
  }
}

