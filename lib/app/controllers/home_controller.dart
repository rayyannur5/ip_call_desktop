import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';
import '../services/sip_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/app_logger.dart';
import 'call_controller.dart';
import 'message_controller.dart';
import 'device_controller.dart';
import 'contact_controller.dart';

const _tag = 'HomeController';

class HomeController extends GetxController {
  final onDevices = false.obs;
  final onContacts = true.obs;
  final onLogs = true.obs;
  final serverState = false.obs;
  final logKey = 0.obs;
  final isRefreshing = false.obs;

  final isDarkMode = false.obs;
  final themeColor = const Color(0xFF2563EB).obs;

  Timer? _serverTimeout;
  
  // Completer to wait for startup initialization
  final Completer<void> initCompleter = Completer<void>();

  // Config from utils table
  int intervalSpeaks = 7000;
  int timeoutCall = 60000;
  int intervalUpdateStatus = 10000;
  final toiletPriority = false.obs;

  @override
  void onInit() {
    super.onInit();
    final storage = Get.find<StorageService>();
    isDarkMode.value = storage.isDarkMode;
    themeColor.value = Color(storage.themeColorValue);
    onContacts.value = storage.isContactsOpen;
    onDevices.value = storage.isDevicesOpen;
    onLogs.value = storage.isLogsOpen;

    // Listen to changes to save state
    ever(onContacts, (bool isOpen) => storage.isContactsOpen = isOpen);
    ever(onDevices, (bool isOpen) => storage.isDevicesOpen = isOpen);
    ever(onLogs, (bool isOpen) => storage.isLogsOpen = isOpen);

    _initServices();
  }

  Future<void> _initServices() async {
    // 1. Connect to database
    try {
      final db = Get.find<DatabaseService>();
      await db.connect();

      // Load utils config
      final utils = await db.getUtils();
      intervalSpeaks = (utils['interval_speaks'] ?? 7000).toInt();
      timeoutCall = (utils['timeout_call'] ?? 60000).toInt();
      intervalUpdateStatus = (utils['interval_update_status'] ?? 10000).toInt();
      toiletPriority.value = (utils['toilet_priority'] ?? 0.0) == 1.0;
    } catch (e, st) {
      logger.e(_tag, 'Database init error', e, st);
    }

    // 2. Connect MQTT
    try {
      final mqtt = Get.find<MqttService>();
      await mqtt.connect();

      // Register MQTT handler for 'internal' heartbeat
      mqtt.addMessageHandler(_handleInternalHeartbeat);
    } catch (e, st) {
      logger.e(_tag, 'MQTT init error', e, st);
    }

    // 3. Register SIP
    try {
      final sip = Get.find<SipService>();
      await sip.register();
    } catch (e, st) {
      logger.e(_tag, 'SIP init error', e, st);
    }

    // 4. Init audio
    try {
      final audio = Get.find<AudioService>();
      await audio.init();
    } catch (e, st) {
      logger.e(_tag, 'Audio init error', e, st);
    }

    if (!initCompleter.isCompleted) {
      initCompleter.complete();
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

  void toggleLogs() {
    onLogs.value = !onLogs.value;
  }

  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
    final storage = Get.find<StorageService>();
    storage.isDarkMode = isDarkMode.value;
    _updateTheme();
  }

  void changeThemeColor(Color color) {
    themeColor.value = color;
    final storage = Get.find<StorageService>();
    storage.themeColorValue = color.value;
    _updateTheme();
  }

  void _updateTheme() {
    Get.changeTheme(
      ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColor.value,
          brightness: isDarkMode.value ? Brightness.dark : Brightness.light,
          surface: isDarkMode.value ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
      ),
    );
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
      toiletPriority.value = (utils['toilet_priority'] ?? 0.0) == 1.0;

      // Reconnect MQTT
      final mqtt = Get.find<MqttService>();
      await mqtt.disconnect();
      await mqtt.connect();

      // Reconnect SIP
      final sip = Get.find<SipService>();
      sip.unregister();
      await sip.register();

      // Re-bind callbacks
      Get.find<CallController>().bindSipCallbacks();

      // Init audio
      final audio = Get.find<AudioService>();
      await audio.init();

      // Reload controllers data
      await Get.find<DeviceController>().loadDevices();
      await Get.find<ContactController>().loadContacts();

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
