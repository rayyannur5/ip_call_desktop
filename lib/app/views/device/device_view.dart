import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/device_controller.dart';

/// Port of Devices.jsx render()
class DeviceView extends GetView<DeviceController> {
  const DeviceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 2),
            ),
          ),
          child: const Text(
            'Daftar Perangkat',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),

        // Device list
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: Obx(() {
              if (controller.devices.isEmpty) {
                return const Center(child: Text('Loading...'));
              }

              return ListView.builder(
                itemCount: controller.devices.length,
                itemBuilder: (context, index) {
                  final room = controller.devices[index];
                  final devices = room['device']
                      as List<Map<String, dynamic>>;
                  final parentMessage =
                      controller.checkMessageForParent(devices);
                  final offlineCount =
                      controller.checkActiveForParent(devices);

                  return ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Row(
                      children: [
                        // Message status dot
                        if (parentMessage == 'e')
                          _buildDot(Colors.red)
                        else if (parentMessage == 'i')
                          _buildDot(Colors.green)
                        else if (parentMessage == 'b')
                          _buildDot(const Color(0xFF60A5FA)),

                        Text(
                          room['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Active status
                        if (offlineCount == 0)
                          const Icon(Icons.circle,
                              color: Color(0xFF22C55E), size: 12)
                        else
                          Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.red, size: 12),
                              const SizedBox(width: 4),
                              Text('$offlineCount',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                    children: devices.map((item) {
                      final msg = item['message'] ?? 'c';
                      Color bgColor;
                      if (msg == 'e') {
                        bgColor = Colors.red[400]!;
                      } else if (msg == 'i') {
                        bgColor = Colors.green[400]!;
                      } else if (msg == 'b') {
                        bgColor = Colors.blue[400]!;
                      } else {
                        bgColor = Colors.white;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['username'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: bgColor == Colors.white
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: item['active'] == true
                                  ? const Color(0xFF22C55E)
                                  : Colors.red,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
