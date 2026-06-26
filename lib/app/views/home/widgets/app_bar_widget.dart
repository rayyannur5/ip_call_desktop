import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/home_controller.dart';
import '../../../controllers/device_controller.dart';
import '../../../services/database_service.dart';
import '../../../services/mqtt_service.dart';
import '../../../services/sip_service.dart';
import '../../settings/settings_view.dart';
import 'clock_widget.dart';

class NurseCallAppBar extends StatelessWidget {
  const NurseCallAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeCtrl = Get.find<HomeController>();
    return Container(
      height: 64,
      color: const Color(0xFF3B82F6), // bg-blue-500
      child: Row(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Image.asset(
              'assets/icons/logo_web_2.png',
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Nurse Call',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Status Indicators (SIP, MQTT, MySQL)
          Obx(() {
            final db = Get.find<DatabaseService>();
            final mqtt = Get.find<MqttService>();
            final sip = Get.find<SipService>();

            Widget buildIndicator(
                IconData icon, String label, bool isConnected) {
              final statusColor = isConnected
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444);
              return Tooltip(
                message: '$label: ${isConnected ? "Terhubung" : "Terputus"}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                    boxShadow: isConnected
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: statusColor,
                  ),
                ),
              );
            }

            return Row(
              children: [
                buildIndicator(
                    Icons.phone_in_talk, 'VoIP/SIP', sip.isRegistered.value),
                buildIndicator(Icons.sensors, 'MQTT Broker', mqtt.isConnected.value),
                buildIndicator(Icons.storage, 'MySQL Database', db.isConnected.value),
              ],
            );
          }),

          // Device count badge
          Obx(() {
            try {
              final deviceCtrl = Get.find<DeviceController>();
              final counts = deviceCtrl.countDevices();
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF15803D), // bg-green-700
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      '${counts['aktif']} Terhubung',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB91C1C), // bg-red-700
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      '${counts['nonaktif']} Terputus',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            } catch (_) {
              return const SizedBox.shrink();
            }
          }),

          const SizedBox(width: 12),

          // Refresh connections button
          Obx(() => IconButton(
                onPressed: homeCtrl.isRefreshing.value
                    ? null
                    : () => homeCtrl.refreshAllConnections(),
                icon: homeCtrl.isRefreshing.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white, size: 24),
                tooltip: 'Refresh Koneksi',
              )),

          const SizedBox(width: 8),

          // Settings button
          IconButton(
            onPressed: () {
              Get.dialog(const SettingsView());
            },
            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
          ),

          // Clock
          const ClockWidget(),
        ],
      ),
    );
  }
}
