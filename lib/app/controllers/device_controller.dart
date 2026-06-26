import 'dart:async';
import 'package:get/get.dart';
import '../services/mqtt_service.dart';
import '../services/database_service.dart';
import 'home_controller.dart';

/// Port of Devices.jsx + CountDeviceOff.jsx
class DeviceController extends GetxController {
  final devices = <Map<String, dynamic>>[].obs;

  int _intervalUpdateStatus = 10000;
  Timer? _resubscribeTimer;

  // Timers per device for active status timeout
  final Map<String, Timer> _deviceTimers = {};

  @override
  void onInit() {
    super.onInit();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final home = Get.find<HomeController>();
      _intervalUpdateStatus = home.intervalUpdateStatus;

      final db = Get.find<DatabaseService>();
      final grouped = await db.getDevicesGroupedByRoom();
      devices.value = grouped;

      final mqtt = Get.find<MqttService>();
      // Subscribe topics for each device if connected
      if (mqtt.isConnected.value) {
        _subscribeAll();
      }

      // Register MQTT handler
      mqtt.addMessageHandler(_handleMqttMessage);

      // Listen to connection status to trigger resubscribe
      ever(mqtt.isConnected, (connected) {
        if (connected) {
          _subscribeAll();
        }
      });

      // Periodic re-subscribe every 30s (from Devices.jsx line 18-54)
      _resubscribeTimer?.cancel();
      _resubscribeTimer =
          Timer.periodic(const Duration(seconds: 30), (_) {
        if (mqtt.isConnected.value) {
          _subscribeAll();
        }
      });
    } catch (e) {
      print('DeviceController load error: $e');
    }
  }

  Future<void> _subscribeAll() async {
    final mqtt = Get.find<MqttService>();
    if (!mqtt.isConnected.value) return;

    for (final room in devices) {
      final deviceList =
          room['device'] as List<Map<String, dynamic>>;
      for (final item in deviceList) {
        if (!mqtt.isConnected.value) return;
        final id = item['id'] as String;

        if (item['mic'] != null) {
          // Bed device
          mqtt.subscribe('call/$id');
          await Future.delayed(const Duration(milliseconds: 20));
          mqtt.subscribe('tidakterjawab/$id');
          await Future.delayed(const Duration(milliseconds: 20));
          mqtt.subscribe('bed/$id');
          await Future.delayed(const Duration(milliseconds: 20));
          mqtt.subscribe('infus/$id');
          await Future.delayed(const Duration(milliseconds: 20));
          mqtt.subscribe('blue/$id');
          await Future.delayed(const Duration(milliseconds: 20));
          mqtt.subscribe('assist/$id');
          await Future.delayed(const Duration(milliseconds: 20));
        } else if (id.contains('room')) {
          // Room device
          mqtt.subscribe(id);
          await Future.delayed(const Duration(milliseconds: 20));
        } else if (id.length > 1) {
          // Toilet
          mqtt.subscribe('toilet/$id');
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
    }

    // Global subscriptions
    if (!mqtt.isConnected.value) return;
    mqtt.subscribe('panggil');
    await Future.delayed(const Duration(milliseconds: 20));
    mqtt.subscribe('internal');
    await Future.delayed(const Duration(milliseconds: 20));
    mqtt.subscribe('aktif');
  }

  void _handleMqttMessage(String topic, String message) {
    // Handle device active status — from Devices.jsx line 101-126
    if (topic.contains('aktif')) {
      for (final room in devices) {
        final deviceList =
            room['device'] as List<Map<String, dynamic>>;
        for (final item in deviceList) {
          if (item['bypass'] == '1' || item['bypass'] == true) {
            item['active'] = true;
            continue;
          }
          if (message == item['id']) {
            item['active'] = true;
            _deviceTimers[item['id']]?.cancel();
            _deviceTimers[item['id']] = Timer(
              Duration(milliseconds: _intervalUpdateStatus),
              () {
                print('timeout ${item['id']}');
                item['active'] = false;
                devices.refresh();
              },
            );
            devices.refresh();
          }
        }
      }
    }

    // Handle device message states (toilet, infus, blue, bed)
    _updateDeviceMessage(topic, message, 'toilet', 7);
    _updateDeviceMessage(topic, message, 'infus', 6);
    _updateDeviceMessage(topic, message, 'blue', 5);
    _updateDeviceMessage(topic, message, 'bed', 4);
  }

  void _updateDeviceMessage(
      String topic, String message, String prefix, int prefixLen) {
    if (!topic.contains(prefix)) return;
    final id = topic.substring(prefixLen);

    for (final room in devices) {
      final deviceList =
          room['device'] as List<Map<String, dynamic>>;
      for (final device in deviceList) {
        if (id == device['id']) {
          device['message'] = message;
          devices.refresh();
        }
      }
    }
  }

  /// Count active/inactive devices
  Map<String, int> countDevices() {
    int nonaktif = 0;
    int aktif = 0;
    for (final room in devices) {
      final deviceList =
          room['device'] as List<Map<String, dynamic>>;
      for (final item in deviceList) {
        if (item['active'] == true) {
          aktif++;
        } else {
          nonaktif++;
        }
      }
    }
    return {'aktif': aktif, 'nonaktif': nonaktif};
  }

  /// Check how many devices in a room are offline
  int checkActiveForParent(List<Map<String, dynamic>> roomDevices) {
    int counter = 0;
    for (final element in roomDevices) {
      if (element['active'] != true) counter++;
    }
    return counter;
  }

  /// Check message state for parent room
  String checkMessageForParent(List<Map<String, dynamic>> roomDevices) {
    for (final element in roomDevices) {
      if (element['message'] != 'c') return element['message'];
    }
    return 'c';
  }

  @override
  void onClose() {
    _resubscribeTimer?.cancel();
    for (final timer in _deviceTimers.values) {
      timer.cancel();
    }
    Get.find<MqttService>().removeMessageHandler(_handleMqttMessage);
    super.onClose();
  }
}
