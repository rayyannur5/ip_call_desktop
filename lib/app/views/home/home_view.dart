import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/call_controller.dart';
import '../../controllers/message_controller.dart';
import '../../services/storage_service.dart';
import '../call/call_panel_view.dart';
import '../contact/contact_view.dart';
import '../message/message_view.dart';
import '../device/device_view.dart';
import '../log/log_view.dart';
import '../settings/settings_view.dart';
import 'widgets/app_bar_widget.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // If not configured, show settings
    final storage = Get.find<StorageService>();
    if (!storage.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.dialog(const SettingsView(), barrierDismissible: false);
      });
    }

    return Scaffold(
      body: Column(
        children: [
          // Top AppBar
          const NurseCallAppBar(),

          // Main content area (60vh equivalent)
          Expanded(
            flex: 6,
            child: Row(
              children: [
                // Call Panel (conditional with animation)
                Obx(() {
                  final callCtrl = Get.find<CallController>();
                  final hasCalls = callCtrl.calls.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: hasCalls ? 200 : 0,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: const Color(0xFFBFDBFE),
                          width: hasCalls ? 4 : 0,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: 200,
                        maxWidth: 200,
                        alignment: Alignment.centerLeft,
                        child: const CallPanelView(),
                      ),
                    ),
                  );
                }),

                // Contact Panel (toggleable with animation)
                Obx(() {
                  final isOpen = controller.onContacts.value;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isOpen ? 280 : 0,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: const Color(0xFFBFDBFE),
                          width: isOpen ? 4 : 0,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: 280,
                        maxWidth: 280,
                        alignment: Alignment.centerLeft,
                        child: const ContactView(),
                      ),
                    ),
                  );
                }),

                // Contact toggle button
                _buildToggleButton(
                  isOpen: controller.onContacts,
                  openIcon: Icons.chevron_left,
                  closedIcon: Icons.chevron_right,
                  onTap: controller.toggleContacts,
                ),

                // Message Panel (main area)
                const Expanded(
                  child: MessageView(),
                ),

                // Device toggle button
                _buildToggleButton(
                  isOpen: controller.onDevices,
                  openIcon: Icons.chevron_right,
                  closedIcon: Icons.chevron_left,
                  onTap: controller.toggleDevices,
                ),

                // Device Panel (toggleable with animation)
                Obx(() {
                  final isOpen = controller.onDevices.value;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isOpen ? 220 : 0,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFFBFDBFE),
                          width: isOpen ? 4 : 0,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: 220,
                        maxWidth: 220,
                        alignment: Alignment.centerLeft,
                        child: const DeviceView(),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Log Panel (30vh equivalent)
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFBFDBFE),
                    width: 4,
                  ),
                ),
              ),
              child: const LogView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required RxBool isOpen,
    required IconData openIcon,
    required IconData closedIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 16,
        color: Colors.white,
        child: Center(
          child: Obx(() => Icon(
                isOpen.value ? openIcon : closedIcon,
                size: 16,
                color: Colors.grey[600],
              )),
        ),
      ),
    );
  }
}
