import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/contact_controller.dart';
import '../../../controllers/call_controller.dart';

/// Port of ListLogTelepon in Kontak.jsx
class HistoryListWidget extends GetView<ContactController> {
  const HistoryListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date picker
        Padding(
          padding: const EdgeInsets.all(8),
          child: Obx(() => GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(controller.currentDate.value) ??
                        DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    controller.setDate(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1D4ED8)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        controller.currentDate.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )),
        ),

        // History list
        Expanded(
          child: Obx(() {
            if (controller.isLoadingHistory.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.histories.isEmpty) {
              return const Center(
                child: Text('Tidak ada data yang ditampilkan'),
              );
            }

            return ListView.builder(
              itemCount: controller.histories.length,
              itemBuilder: (context, index) {
                final h = controller.histories[index];
                final categoryId = h['category_history_id'] ?? '0';

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h['username'] ?? '',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Direction icon
                                Icon(
                                  categoryId == '3'
                                      ? Icons.call_made
                                      : Icons.call_received,
                                  size: 14,
                                  color: categoryId == '2'
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${h['category_name'] ?? ''}${h['duration'] != null ? ' | ${h['duration']}' : ''}\n${h['timestamp'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final callCtrl = Get.find<CallController>();
                          callCtrl.call(
                            h['bed_id'] ?? '',
                            h['phone'] ?? '',
                            h['username'] ?? '',
                          );
                        },
                        icon: const Icon(Icons.call,
                            color: Color(0xFF34B1EB), size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
