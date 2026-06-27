import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/device_controller.dart';

/// Port of Devices.jsx render()
class DeviceView extends GetView<DeviceController> {
  const DeviceView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Header
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.15),
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.primary, width: 3),
            ),
          ),
          child: Text(
            'Daftar Perangkat',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
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
                      Color textColor;
                      
                      if (msg == 'e') {
                        bgColor = Colors.red[400]!;
                        textColor = Colors.white;
                      } else if (msg == 'i') {
                        bgColor = Colors.green[400]!;
                        textColor = Colors.white;
                      } else if (msg == 'b') {
                        bgColor = Colors.blue[400]!;
                        textColor = Colors.white;
                      } else {
                        bgColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
                        textColor = theme.colorScheme.onSurface;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          ),
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
                                  color: textColor,
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
