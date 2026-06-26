import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/log_controller.dart';
import '../../controllers/home_controller.dart';

/// Port of Log.jsx — log table with date filter
class LogView extends StatelessWidget {
  const LogView({super.key});

  Color _getCategoryColor(dynamic categoryLogId) {
    final idStr = categoryLogId?.toString();
    switch (idStr) {
      case '1': return const Color(0xFFDC2626); // red - darurat
      case '3': return const Color(0xFF3B82F6); // blue - code blue
      case '4': return const Color(0xFF22C55E); // green - infus
      case '5': return const Color(0xFFF97316); // orange - perawat
      default: return const Color(0xFFFACC15);  // yellow - telepon
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Watch logKey for forced refreshes
      final homeCtrl = Get.find<HomeController>();
      final _ = homeCtrl.logKey.value;

      final ctrl = Get.find<LogController>();

      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LOG',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(ctrl.currentDate.value) ??
                                  DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          ctrl.setDate(
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF93C5FD), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14),
                            const SizedBox(width: 4),
                            Text(ctrl.currentDate.value,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => ctrl.loadLogs(),
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Header row (Fixed at top)
            Container(
              color: const Color(0xFF60A5FA),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text('Timestamp',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  SizedBox(
                    width: 200,
                    child: Text('Kategori',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Expanded(
                    child: Text('Ruang',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  SizedBox(
                    width: 150,
                    child: Text('Waktu',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Table Data (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Data rows
                    if (ctrl.logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Tidak ada data yang ditampilkan'),
                      )
                    else
                      ...ctrl.logs.map((log) {
                        final rawTime = log['time'];
                        final time = rawTime is int
                            ? rawTime
                            : int.tryParse(rawTime?.toString() ?? '0') ?? 0;
                        
                        final presenceRaw = log['nurse_presence'];
                        final nursePresence = presenceRaw == 1 ||
                            presenceRaw == true ||
                            presenceRaw?.toString() == '1' ||
                            presenceRaw?.toString() == 'true';
                        
                        final duration = nursePresence
                            ? ctrl.getWaktuTerbilang(time)
                            : '0 detik';

                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                  color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 180,
                                child: Text(
                                  log['timestamp']?.toString() ?? '',
                                  style:
                                      const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.only(
                                          right: 8),
                                      color: _getCategoryColor(
                                          log['category_log_id']),
                                    ),
                                    Text(
                                      log['name']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  log['username']?.toString() ?? '',
                                  style:
                                      const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(
                                  duration,
                                  style:
                                      const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
