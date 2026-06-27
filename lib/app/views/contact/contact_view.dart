import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/contact_controller.dart';
import 'widgets/contact_list_widget.dart';
import 'widgets/history_list_widget.dart';

/// Port of Kontak.jsx — Tab bar: Kontak / Riwayat Telepon
class ContactView extends GetView<ContactController> {
  const ContactView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Obx(() => Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.isKontak.value = true,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: controller.isKontak.value
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: controller.isKontak.value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people,
                            size: 18,
                            color: controller.isKontak.value
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kontak',
                            style: TextStyle(
                              color: controller.isKontak.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.isKontak.value = false,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: !controller.isKontak.value
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: !controller.isKontak.value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 18,
                            color: !controller.isKontak.value
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Riwayat Telepon',
                            style: TextStyle(
                              color: !controller.isKontak.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )),

        // Content
        Expanded(
          child: Obx(() => controller.isKontak.value
              ? const ContactListWidget()
              : const HistoryListWidget()),
        ),
      ],
    );
  }
}
