import 'dart:io';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';
import '../services/sip_service.dart';
import '../services/audio_service.dart';
import '../services/platform/linux_wifi_service.dart';
import '../services/platform/linux_volume_service.dart';
import '../controllers/home_controller.dart';
import '../controllers/call_controller.dart';
import '../controllers/message_controller.dart';
import '../controllers/device_controller.dart';
import '../controllers/contact_controller.dart';
import '../controllers/log_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/platform/linux_wifi_controller.dart';
import '../controllers/platform/linux_volume_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put(StorageService());
    Get.put(DatabaseService());
    Get.put(MqttService());
    Get.put(SipService());
    Get.put(AudioService());

    // Controllers
    Get.put(SettingsController());
    Get.put(HomeController());
    Get.put(CallController());
    Get.put(MessageController());
    Get.put(DeviceController());
    Get.put(ContactController());
    Get.put(LogController());

    // Linux only
    if (Platform.isLinux) {
      Get.put(LinuxWifiService());
      Get.put(LinuxVolumeService());
      Get.put(LinuxWifiController());
      Get.put(LinuxVolumeController());
    }
  }
}
