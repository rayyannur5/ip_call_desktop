import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';
import '../services/sip_service.dart';
import '../services/audio_service.dart';

class SettingsController extends GetxController {
  late final TextEditingController adminPasswordCtrl;
  final isAdminUnlocked = false.obs;

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

      final audio = Get.find<AudioService>();
      await audio.init();

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
