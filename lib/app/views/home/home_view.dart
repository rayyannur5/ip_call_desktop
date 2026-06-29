import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/call_controller.dart';
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
    if (!storage.isConfigured && Get.isDialogOpen != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.isDialogOpen != true) {
          Get.dialog(const SettingsView(), barrierDismissible: false);
        }
      });
    }

    return Obx(() {
      final isDark = controller.isDarkMode.value;
      final tColor = controller.themeColor.value;
      return Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: tColor,
            brightness: isDark ? Brightness.dark : Brightness.light,
            surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
        ),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/icons/bg-20.png'),
                fit: BoxFit.cover,
                opacity: 1.0,
              ),
            ),
            child: Stack(
              children: [
                // Main layout Column
                Column(
                  children: [
                    // Top AppBar
                    const NurseCallAppBar(),

                    // Main content area
                    Expanded(
                      child: Stack(
                        children: [
                          // Main panel Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Call Panel (conditional with animation)
                              Obx(() {
                                final callCtrl = Get.find<CallController>();
                                final hasCalls = callCtrl.calls.isNotEmpty;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  width: hasCalls ? 200 : 0,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Theme.of(context).colorScheme.outlineVariant,
                                        width: hasCalls ? 2.0 : 0,
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
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  width: isOpen ? 320 : 0,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Theme.of(context).colorScheme.outlineVariant,
                                        width: isOpen ? 2.0 : 0,
                                      ),
                                    ),
                                  ),
                                  child: ClipRect(
                                    child: OverflowBox(
                                      minWidth: 320,
                                      maxWidth: 320,
                                      alignment: Alignment.centerLeft,
                                      child: const ContactView(),
                                    ),
                                  ),
                                );
                              }),

                              // Message Panel (main area)
                              const Expanded(
                                child: MessageView(),
                              ),

                              // Device Panel (toggleable with animation)
                              Obx(() {
                                final isOpen = controller.onDevices.value;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  width: isOpen ? 320 : 0,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: Theme.of(context).colorScheme.outlineVariant,
                                        width: isOpen ? 2.0 : 0,
                                      ),
                                    ),
                                  ),
                                  child: ClipRect(
                                    child: OverflowBox(
                                      minWidth: 320,
                                      maxWidth: 320,
                                      alignment: Alignment.centerLeft,
                                      child: const DeviceView(),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),

                          // Floating Contact toggle button
                          Obx(() {
                            final isOpen = controller.onContacts.value;
                            final callCtrl = Get.find<CallController>();
                            final hasCalls = callCtrl.calls.isNotEmpty;
                            final leftOffset = (hasCalls ? 200.0 : 0.0) + (isOpen ? 320.0 : 0.0);
                            final targetLeft = leftOffset == 0.0 ? 0.0 : leftOffset - 9.0;
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              left: targetLeft,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildFloatingToggleButton(
                                  isOpen: controller.onContacts,
                                  openIcon: Icons.chevron_left,
                                  closedIcon: Icons.chevron_right,
                                  onTap: controller.toggleContacts,
                                ),
                              ),
                            );
                          }),

                          // Floating Device toggle button
                          Obx(() {
                            final isOpen = controller.onDevices.value;
                            final rightOffset = isOpen ? 320.0 : 0.0;
                            final targetRight = rightOffset == 0.0 ? 0.0 : rightOffset - 9.0;
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              right: targetRight,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildFloatingToggleButton(
                                  isOpen: controller.onDevices,
                                  openIcon: Icons.chevron_right,
                                  closedIcon: Icons.chevron_left,
                                  onTap: controller.toggleDevices,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Log Panel
                    Obx(() {
                      final isOpen = controller.onLogs.value;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        height: isOpen ? 260 : 0,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              width: 2.0,
                            ),
                          ),
                        ),
                        child: ClipRect(
                          child: OverflowBox(
                            minHeight: 260,
                            maxHeight: 260,
                            alignment: Alignment.topCenter,
                            child: const LogView(),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // Floating horizontal toggle button
                Obx(() {
                  final isOpen = controller.onLogs.value;
                  final bottomOffset = isOpen ? 260.0 : 0.0;
                  final targetBottom = bottomOffset == 0.0 ? 0.0 : bottomOffset - 9.0;
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    bottom: targetBottom,
                    child: Center(
                      child: _buildFloatingHorizontalToggleButton(
                        isOpen: controller.onLogs,
                        openIcon: Icons.keyboard_arrow_down,
                        closedIcon: Icons.keyboard_arrow_up,
                        onTap: controller.toggleLogs,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFloatingToggleButton({
    required RxBool isOpen,
    required IconData openIcon,
    required IconData closedIcon,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 18,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Obx(() => Icon(
                    isOpen.value ? openIcon : closedIcon,
                    size: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  )),
            ),
          ),
        );
      }
    );
  }

  Widget _buildFloatingHorizontalToggleButton({
    required RxBool isOpen,
    required IconData openIcon,
    required IconData closedIcon,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 56,
            height: 18,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Obx(() => Icon(
                    isOpen.value ? openIcon : closedIcon,
                    size: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  )),
            ),
          ),
        );
      }
    );
  }
}
