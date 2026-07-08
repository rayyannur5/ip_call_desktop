import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';
import '../services/sip_service.dart';
import '../services/audio_service.dart';
import '../services/app_logger.dart';
import 'home_controller.dart';
import 'message_controller.dart';
import 'device_controller.dart';
import 'call_controller.dart';
import 'contact_controller.dart';

const _tag = 'SettingsController';

class SettingsController extends GetxController {
  late final TextEditingController adminPasswordCtrl;
  final isAdminUnlocked = false.obs;

  Future<bool> setSystemDate(DateTime dateTime) async {
    if (!Platform.isLinux) return false;
    try {
      final dateStr = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      
      // Try running without sudo first (in case application is running as root)
      var result = await Process.run('date', ['-s', dateStr]);
      if (result.exitCode != 0) {
        // If it fails, try with sudo
        result = await Process.run('sudo', ['date', '-s', dateStr]);
      }
      
      return result.exitCode == 0;
    } catch (e, st) {
      logger.e(_tag, 'Set system date error', e, st);
      return false;
    }
  }

  Future<bool> setSystemDateOnly(DateTime date) async {
    if (!Platform.isLinux) return false;
    try {
      final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      var result = await Process.run('date', ['+%Y%m%d', '-s', dateStr]);
      if (result.exitCode != 0) {
        result = await Process.run('sudo', ['date', '+%Y%m%d', '-s', dateStr]);
      }
      return result.exitCode == 0;
    } catch (e, st) {
      logger.e(_tag, 'Set system date only error', e, st);
      return false;
    }
  }

  Future<bool> setSystemTimeOnly(TimeOfDay time) async {
    if (!Platform.isLinux) return false;
    try {
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
      var result = await Process.run('date', ['+%T', '-s', timeStr]);
      if (result.exitCode != 0) {
        result = await Process.run('sudo', ['date', '+%T', '-s', timeStr]);
      }
      return result.exitCode == 0;
    } catch (e, st) {
      logger.e(_tag, 'Set system time only error', e, st);
      return false;
    }
  }

  late final TextEditingController serverHostCtrl;
  late final TextEditingController mqttPortCtrl;
  late final TextEditingController dbPortCtrl;
  late final TextEditingController dbUsernameCtrl;
  late final TextEditingController dbPasswordCtrl;
  late final TextEditingController dbNameCtrl;
  late final TextEditingController sipDomainCtrl;
  late final TextEditingController sipPortCtrl;
  late final TextEditingController sipUsernameCtrl;
  late final TextEditingController sipPasswordCtrl;
  late final TextEditingController sipWsUrlCtrl;

  final isTesting = false.obs;
  final testResult = ''.obs;

  @override
  void onInit() {
    super.onInit();
    adminPasswordCtrl = TextEditingController();
    final s = Get.find<StorageService>();
    serverHostCtrl = TextEditingController(text: s.serverHost);
    mqttPortCtrl = TextEditingController(text: s.mqttPort.toString());
    dbPortCtrl = TextEditingController(text: s.dbPort.toString());
    dbUsernameCtrl = TextEditingController(text: s.dbUsername);
    dbPasswordCtrl = TextEditingController(text: s.dbPassword);
    dbNameCtrl = TextEditingController(text: s.dbName);
    sipDomainCtrl = TextEditingController(
        text: s.sipDomain.isNotEmpty ? s.sipDomain : s.serverHost);
    sipPortCtrl = TextEditingController(text: s.sipPort.toString());
    sipUsernameCtrl = TextEditingController(text: s.sipUsername);
    sipPasswordCtrl = TextEditingController(text: s.sipPassword);
    sipWsUrlCtrl = TextEditingController(
        text: s.sipWsUrl.isNotEmpty
            ? s.sipWsUrl
            : (s.serverHost.isNotEmpty ? 'ws://${s.serverHost}:8088/ws' : ''));
  }

  Future<void> testConnection() async {
    isTesting.value = true;
    testResult.value = '';

    // Temporarily save to test
    _saveToStorage();

    final db = Get.find<DatabaseService>();
    final ok = await db.testConnection();
    testResult.value = ok ? 'Koneksi berhasil!' : 'Koneksi gagal!';
    isTesting.value = false;
  }

  void _saveToStorage() {
    final s = Get.find<StorageService>();
    final host = serverHostCtrl.text.trim();
    s.serverHost = host;
    s.mqttPort = int.tryParse(mqttPortCtrl.text) ?? 1883;
    s.dbPort = int.tryParse(dbPortCtrl.text) ?? 3306;
    s.dbUsername = dbUsernameCtrl.text;
    s.dbPassword = dbPasswordCtrl.text;
    s.dbName = dbNameCtrl.text;

    final sipDomain = sipDomainCtrl.text.trim();
    s.sipDomain = sipDomain.isNotEmpty ? sipDomain : host;

    s.sipPort = int.tryParse(sipPortCtrl.text) ?? 5060;
    s.sipUsername = sipUsernameCtrl.text;
    s.sipPassword = sipPasswordCtrl.text;

    final sipWs = sipWsUrlCtrl.text.trim();
    s.sipWsUrl = sipWs.isNotEmpty ? sipWs : 'ws://$host:8088/ws';
  }

  Future<void> save() async {
    _saveToStorage();

    // Reconnect services
    try {
      final db = Get.find<DatabaseService>();
      await db.disconnect();
      await db.connect();

      final mqtt = Get.find<MqttService>();
      await mqtt.disconnect();
      await mqtt.connect();

      final sip = Get.find<SipService>();
      sip.unregister();
      await sip.register();

      // Re-bind callbacks
      Get.find<CallController>().bindSipCallbacks();

      final audio = Get.find<AudioService>();
      await audio.init();

      // Reload controllers data
      await Get.find<DeviceController>().loadDevices();
      await Get.find<ContactController>().loadContacts();

      Get.snackbar('Berhasil', 'Settings disimpan dan service terhubung ulang',
          snackPosition: SnackPosition.bottom);
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghubungkan: $e',
          snackPosition: SnackPosition.bottom);
    }
  }

  void resetAdminState() {
    isAdminUnlocked.value = false;
    adminPasswordCtrl.clear();
    testResult.value = '';
  }

  void checkAdminPassword() {
    if (adminPasswordCtrl.text == '12orangepi12') {
      isAdminUnlocked.value = true;
      testResult.value = '';
    } else {
      testResult.value = 'Password admin salah!';
    }
  }

  Future<void> rebootDevice() async {
    try {
      Get.snackbar('Rebooting', 'Sistem akan segera dijalankan ulang...',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Colors.orange,
          colorText: Colors.white);
      await Future.delayed(const Duration(seconds: 1));
      await Process.run('sudo', ['reboot']);
    } catch (e) {
      Get.snackbar('Error', 'Gagal memicu reboot: $e',
          snackPosition: SnackPosition.bottom);
    }
  }

  Future<void> resetData() async {
    try {
      final mqtt = Get.find<MqttService>();
      
      // Clear local memory message queue
      try {
        final msgCtrl = Get.find<MessageController>();
        msgCtrl.clearAllMessages();

        final callCtrl = Get.find<CallController>();
        callCtrl.calls.clear();
        callCtrl.callSeconds.clear();
        callCtrl.onSession.value = false;
        callCtrl.isAnswering.value = false;

        final storage = Get.find<StorageService>();
        storage.appState = '';
        storage.appStateCalls = '';
        storage.appStateMessages = '';
      } catch (_) {}

      // Clear MQTT retained topics by publishing empty strings to the relevant device/global topics
      if (mqtt.isConnected.value) {
        try {
          final deviceCtrl = Get.find<DeviceController>();
          final listDevices = deviceCtrl.devices;
          for (final room in listDevices) {
            final deviceList = room['device'] as List<dynamic>;
            for (final item in deviceList) {
              final id = item['id'] as String;
              if (item['mic'] != null) {
                mqtt.publish('call/$id', '', retain: true);
                mqtt.publish('tidakterjawab/$id', '', retain: true);
                mqtt.publish('bed/$id', '', retain: true);
                mqtt.publish('infus/$id', '', retain: true);
                mqtt.publish('blue/$id', '', retain: true);
                mqtt.publish('assist/$id', '', retain: true);
              } else if (id.contains('room')) {
                mqtt.publish(id, '', retain: true);
              } else if (id.length > 1) {
                mqtt.publish('toilet/$id', '', retain: true);
              }
            }
          }
        } catch (_) {}
        mqtt.publish('panggil', '', retain: true);
        mqtt.publish('aktif', '', retain: true);
        mqtt.publish('internal', '', retain: true);
      }

      // Update UI log status
      try {
        final home = Get.find<HomeController>();
        home.logKey.value++;
      } catch (_) {}

      Get.snackbar('Berhasil', 'Antrean pesan aktif dan retained MQTT berhasil di-reset!',
          snackPosition: SnackPosition.bottom,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Gagal mereset data: $e',
          snackPosition: SnackPosition.bottom);
    }
  }

  @override
  void onClose() {
    adminPasswordCtrl.dispose();
    serverHostCtrl.dispose();
    mqttPortCtrl.dispose();
    dbPortCtrl.dispose();
    dbUsernameCtrl.dispose();
    dbPasswordCtrl.dispose();
    dbNameCtrl.dispose();
    sipDomainCtrl.dispose();
    sipPortCtrl.dispose();
    sipUsernameCtrl.dispose();
    sipPasswordCtrl.dispose();
    sipWsUrlCtrl.dispose();
    super.onClose();
  }
}
