import 'package:get/get.dart';
import '../../services/platform/linux_wifi_service.dart';

class LinuxWifiController extends GetxController {
  final wifiList = <Map<String, String>>[].obs;
  final activeConnection = ''.obs;
  final isScanning = false.obs;
  final isConnecting = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    final service = Get.find<LinuxWifiService>();
    activeConnection.value = await service.getActiveConnection();
  }

  Future<void> scan() async {
    isScanning.value = true;
    final service = Get.find<LinuxWifiService>();
    wifiList.value = await service.scanWifi();
    await refreshStatus();
    isScanning.value = false;
  }

  Future<bool> connect(String ssid, String password) async {
    isConnecting.value = true;
    final service = Get.find<LinuxWifiService>();
    final result = await service.connectWifi(ssid, password);
    await refreshStatus();
    isConnecting.value = false;
    return result;
  }

  Future<void> disconnect() async {
    if (activeConnection.value.isEmpty) return;
    final service = Get.find<LinuxWifiService>();
    await service.disconnect(activeConnection.value);
    await refreshStatus();
  }
}
