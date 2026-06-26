import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';
import '../services/sip_service.dart';
import '../services/audio_service.dart';
import 'call_controller.dart';
import 'message_controller.dart';

class HomeController extends GetxController {
  final onDevices = false.obs;
  final onContacts = true.obs;
  final serverState = false.obs;
  final logKey = 0.obs;
  final isRefreshing = false.obs;

  Timer? _serverTimeout;

  // Config from utils table
  int intervalSpeaks = 7000;
  int timeoutCall = 60000;
  int intervalUpdateStatus = 10000;

  @override
  void onInit() {
    super.onInit();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Connect to database
      final db = Get.find<DatabaseService>();
      await db.connect();

      // Load utils config
      final utils = await db.getUtils();
      intervalSpeaks =
          (utils['interval_speaks'] ?? 7000).toInt();
      timeoutCall =
          (utils['timeout_call'] ?? 60000).toInt();
      intervalUpdateStatus =
          (utils['interval_update_status'] ?? 10000).toInt();

      // Connect MQTT
      final mqtt = Get.find<MqttService>();
      await mqtt.connect();

      // Register MQTT handler for 'internal' heartbeat
      mqtt.addMessageHandler(_handleInternalHeartbeat);

      // Register SIP
      final sip = Get.find<SipService>();
      await sip.register();

      // Init audio
      final audio = Get.find<AudioService>();
      await audio.init();
    } catch (e) {
      print('HomeController init error: $e');
    }
  }

  void _handleInternalHeartbeat(String topic, String message) {
    if (topic.contains('internal')) {
      serverState.value = true;
      _serverTimeout?.cancel();
      _serverTimeout = Timer(const Duration(seconds: 10), () {
        serverState.value = false;
      });
    }
  }

  void toggleDevices() {
    onDevices.value = !onDevices.value;
  }

  void toggleContacts() {
    onContacts.value = !onContacts.value;
  }

  Future<void> refreshAllConnections() async {
    final callCtrl = Get.find<CallController>();
    final msgCtrl = Get.find<MessageController>();

    if (callCtrl.calls.isNotEmpty || msgCtrl.messages.isNotEmpty) {
      Get.dialog(
        AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Refresh Ditolak'),
            ],
          ),
          content: const Text(
            'Tidak dapat melakukan refresh koneksi karena saat ini terdapat panggilan atau pesan darurat yang sedang aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.close(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    isRefreshing.value = true;
    try {
      // Reconnect Database
      final db = Get.find<DatabaseService>();
      await db.disconnect();
      await db.connect();

      // Load config again
      final utils = await db.getUtils();
      intervalSpeaks = (utils['interval_speaks'] ?? 7000).toInt();
      timeoutCall = (utils['timeout_call'] ?? 60000).toInt();
      intervalUpdateStatus = (utils['interval_update_status'] ?? 10000).toInt();

      // Reconnect MQTT
      final mqtt = Get.find<MqttService>();
      await mqtt.disconnect();
      await mqtt.connect();

      // Reconnect SIP
      final sip = Get.find<SipService>();
      sip.unregister();
      await sip.register();

      // Init audio
      final audio = Get.find<AudioService>();
      await audio.init();

      Get.snackbar('Berhasil', 'Seluruh koneksi telah di-refresh',
          snackPosition: SnackPosition.bottom);
    } catch (e) {
      Get.snackbar('Error', 'Gagal me-refresh koneksi: $e',
          snackPosition: SnackPosition.bottom);
    } finally {
      isRefreshing.value = false;
    }
  }

  @override
  void onClose() {
    _serverTimeout?.cancel();
    Get.find<MqttService>().removeMessageHandler(_handleInternalHeartbeat);
    super.onClose();
  }
}
