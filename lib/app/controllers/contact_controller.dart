import 'dart:async';
import 'package:get/get.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';
import 'home_controller.dart';

/// Port of Kontak.jsx + KontakList.jsx
class ContactController extends GetxController {
  final isKontak = true.obs; // Tab state

  // Contact list
  final beds = <Map<String, dynamic>>[].obs;
  final bedsFiltered = <Map<String, dynamic>>[].obs;
  final isLoadingBeds = true.obs;

  // 2-way devices for contact list with active status
  final devices2w = <Map<String, dynamic>>[].obs;
  final Map<String, Timer> _deviceTimers = {};
  int _intervalUpdateStatus = 10000;

  // History
  final histories = <Map<String, dynamic>>[].obs;
  final isLoadingHistory = true.obs;
  final currentDate = ''.obs;

  @override
  void onInit() {
    super.onInit();

    // Set default date
    final now = DateTime.now();
    currentDate.value =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final home = Get.find<HomeController>();
      _intervalUpdateStatus = home.intervalUpdateStatus;

      final db = Get.find<DatabaseService>();

      // Load beds
      final allBeds = await db.getAllBeds();
      beds.value = allBeds;
      bedsFiltered.value = allBeds;
      isLoadingBeds.value = false;

      // Load 2-way devices
      final d2w = await db.getDevices2Way();
      devices2w.value = d2w;

      // Register MQTT handler for active status
      final mqtt = Get.find<MqttService>();
      mqtt.addMessageHandler(_handleMqttMessage);

      // Load history
      loadHistory(currentDate.value);
    } catch (e) {
      print('ContactController load error: $e');
      isLoadingBeds.value = false;
    }
  }

  void _handleMqttMessage(String topic, String message) {
    if (topic.contains('aktif')) {
      for (final room in devices2w) {
        final deviceList =
            room['device'] as List<Map<String, dynamic>>;
        for (final item in deviceList) {
          if (message == item['id']) {
            item['active'] = true;
            _deviceTimers[item['id']]?.cancel();
            _deviceTimers[item['id']] = Timer(
              Duration(milliseconds: _intervalUpdateStatus),
              () {
                print('timeout di kontak ${item['id']}');
                item['active'] = false;
                devices2w.refresh();
              },
            );
            devices2w.refresh();
          }
        }
      }
    }
  }

  final searchQuery = ''.obs;

  List<Map<String, dynamic>> get filteredDevices2w {
    if (searchQuery.value.isEmpty) {
      return devices2w;
    }

    final query = searchQuery.value.toLowerCase();
    List<Map<String, dynamic>> result = [];

    for (final room in devices2w) {
      final devices = room['device'] as List<Map<String, dynamic>>;
      final filteredDevices = devices.where((item) {
        final name = (item['username'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();

      if (filteredDevices.isNotEmpty) {
        result.add({
          'id': room['id'],
          'name': room['name'],
          'device': filteredDevices,
        });
      }
    }
    return result;
  }

  /// Search contacts — from Kontak.jsx handleOnChange
  void search(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      bedsFiltered.value = beds.toList();
    } else {
      bedsFiltered.value = beds
          .where((bed) => (bed['username'] ?? '')
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }
  }

  /// Group beds by room — from Kontak.jsx pengelompokkan()
  List<Map<String, dynamic>> pengelompokkan() {
    if (bedsFiltered.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> grouping = {};
    for (final bed in bedsFiltered) {
      final roomId = (bed['room_id'] ?? '').toString();
      grouping.putIfAbsent(roomId, () => []);
      grouping[roomId]!.add(bed);
    }

    List<Map<String, dynamic>> result = [];
    for (final entry in grouping.entries) {
      final value = entry.value;
      final bedName = (value[0]['username'] ?? '').split(' ');
      final name = bedName.length > 1 ? bedName[1] : bedName[0];

      // Check if at least one device has tw != 0
      final hasTw = value.any((v) => v['tw'] != '0');
      if (hasTw) {
        result.add({
          'name': name,
          'device': value,
        });
      }
    }

    return result;
  }

  /// Load call history by date
  Future<void> loadHistory(String date) async {
    isLoadingHistory.value = true;
    try {
      final db = Get.find<DatabaseService>();
      histories.value = await db.getHistoryByDate(date);
    } catch (e) {
      print('Load history error: $e');
    }
    isLoadingHistory.value = false;
  }

  void setDate(String date) {
    currentDate.value = date;
    loadHistory(date);
  }

  @override
  void onClose() {
    for (final timer in _deviceTimers.values) {
      timer.cancel();
    }
    Get.find<MqttService>().removeMessageHandler(_handleMqttMessage);
    super.onClose();
  }
}
