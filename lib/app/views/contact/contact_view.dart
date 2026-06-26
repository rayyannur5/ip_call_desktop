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
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: controller.isKontak.value
                                ? const Color(0xFF1D4ED8)
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Kontak',
                          style: TextStyle(
                            color: controller.isKontak.value
                                ? const Color(0xFF1D4ED8)
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: !controller.isKontak.value
                                ? const Color(0xFF1D4ED8)
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Riwayat Telepon',
                          style: TextStyle(
                            color: !controller.isKontak.value
                                ? const Color(0xFF1D4ED8)
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
