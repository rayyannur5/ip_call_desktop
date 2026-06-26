import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../services/storage_service.dart';
import '../platform/linux_wifi_view.dart';
import '../platform/linux_volume_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final controller = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    controller.resetAdminState();
  }

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (storage.isConfigured)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Linux-specific features (Accessible to everyone at the top)
              if (Platform.isLinux) ...[
                _buildSectionTitle('Sistem'),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.dialog(const LinuxWifiView());
                        },
                        icon: const Icon(Icons.wifi),
                        label: const Text('WiFi Settings'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.dialog(const LinuxVolumeView());
                        },
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Volume Control'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Credentials settings (Locked behind admin password)
              Obx(() {
                if (!controller.isAdminUnlocked.value) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionTitle('Credentials & Connection Settings'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller.adminPasswordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password Admin',
                                hintText: 'Masukkan password untuk mengedit',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              onSubmitted: (_) => controller.checkAdminPassword(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: controller.checkAdminPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Unlock'),
                          ),
                        ],
                      ),
                      if (controller.testResult.value.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          controller.testResult.value,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Server Host'),
                    _buildField('Server Host', controller.serverHostCtrl,
                        hint: 'IP address or hostname'),
                    const SizedBox(height: 16),

                    // MQTT Section
                    _buildSectionTitle('MQTT'),
                    _buildField('Port', controller.mqttPortCtrl),
                    const SizedBox(height: 16),

                    // Database Section
                    _buildSectionTitle('Database'),
                    _buildField('Port', controller.dbPortCtrl),
                    _buildField('Username', controller.dbUsernameCtrl),
                    _buildField('Password', controller.dbPasswordCtrl,
                        obscure: true),
                    _buildField('Database Name', controller.dbNameCtrl),
                    const SizedBox(height: 16),

                    // SIP Section
                    _buildSectionTitle('SIP'),
                    _buildField('Port', controller.sipPortCtrl),
                    _buildField('Username', controller.sipUsernameCtrl),
                    _buildField('Password', controller.sipPasswordCtrl,
                        obscure: true),
                    const SizedBox(height: 16),

                    // Test & Save buttons
                    if (controller.testResult.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          controller.testResult.value,
                          style: TextStyle(
                            color: controller.testResult.value.contains('berhasil')
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.isTesting.value
                                ? null
                                : controller.testConnection,
                            child: controller.isTesting.value
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Test Connection'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await controller.save();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool obscure = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
