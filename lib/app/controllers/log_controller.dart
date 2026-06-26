import 'package:get/get.dart';
import '../services/database_service.dart';

import '../controllers/home_controller.dart';

/// Port of Log.jsx
class LogController extends GetxController {
  final logs = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final currentDate = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    currentDate.value =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    loadLogs();

    // Listen to logKey updates to refresh logs
    final home = Get.find<HomeController>();
    ever(home.logKey, (_) => loadLogs());
  }

  Future<void> loadLogs() async {
    isLoading.value = true;
    try {
      final db = Get.find<DatabaseService>();
      logs.value = await db.getLogsByDate(currentDate.value);
    } catch (e) {
      print('Load logs error: $e');
    }
    isLoading.value = false;
  }

  void setDate(String date) {
    currentDate.value = date;
    loadLogs();
  }

  /// Format duration to Indonesian text — from Log.jsx getWaktuTerbilang()
  String getWaktuTerbilang(int detikAwal) {
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
}
