import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/contact_controller.dart';
import '../../../controllers/call_controller.dart';

/// Port of KontakList.jsx — grouped contacts with active status
class ContactListWidget extends GetView<ContactController> {
  const ContactListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            onChanged: controller.search,
            decoration: InputDecoration(
              hintText: 'Cari Nama Kamar',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),

        // Device list grouped by room
        Expanded(
          child: Obx(() {
            final rooms = controller.filteredDevices2w;
            if (rooms.isEmpty) {
              return const Center(child: Text('Loading...'));
            }

            return ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                final devices = room['device']
                    as List<Map<String, dynamic>>;

                return ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    room['name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  children: devices
                      .where((item) => item['tw']?.toString() == '1')
                      .map((item) => _buildContactItem(context, item))
                      .toList(),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildContactItem(BuildContext context, Map<String, dynamic> item) {
    final isActive = item['active'] == true;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['username'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            IconButton(
              onPressed: () {
                final callCtrl = Get.find<CallController>();
                callCtrl.call(
                  item['id'],
                  item['phone'] ?? '',
                  item['username'] ?? '',
                );
              },
              icon: Icon(Icons.call,
                  color: theme.colorScheme.primary, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            )
          else
            Icon(Icons.circle, color: theme.colorScheme.error, size: 12),
        ],
      ),
    );
  }
}
