import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/platform/linux_wifi_controller.dart';

class LinuxWifiView extends GetView<LinuxWifiController> {
  const LinuxWifiView({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('WiFi Settings',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            // Active connection
            Obx(() => controller.activeConnection.value.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Terhubung: ${controller.activeConnection.value}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.disconnect,
                          child: const Text('Disconnect',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink()),

            // Scan button
            Obx(() => ElevatedButton.icon(
                  onPressed:
                      controller.isScanning.value ? null : controller.scan,
                  icon: controller.isScanning.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(
                      controller.isScanning.value ? 'Scanning...' : 'Scan'),
                )),
            const SizedBox(height: 12),

            // WiFi list
            Expanded(
              child: Obx(() {
                if (controller.wifiList.isEmpty) {
                  return const Center(child: Text('Belum di-scan'));
                }

                return ListView.builder(
                  itemCount: controller.wifiList.length,
                  itemBuilder: (context, index) {
                    final wifi = controller.wifiList[index];
                    final inUse = wifi['in_use'] == '*';

                    return ListTile(
                      leading: Icon(
                        Icons.wifi,
                        color: inUse ? Colors.green : Colors.grey,
                      ),
                      title: Text(wifi['ssid'] ?? ''),
                      subtitle: Text(
                          'Signal: ${wifi['signal']}% | ${wifi['security']}'),
                      trailing: inUse
                          ? const Text('Connected',
                              style: TextStyle(color: Colors.green))
                          : TextButton(
                              onPressed: () =>
                                  _showConnectDialog(context, wifi['ssid']!),
                              child: const Text('Connect'),
                            ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectDialog(BuildContext context, String ssid) {
    Get.dialog(
      _WifiConnectDialog(ssid: ssid, controller: controller),
    );
  }
}

class _WifiConnectDialog extends StatefulWidget {
  final String ssid;
  final LinuxWifiController controller;

  const _WifiConnectDialog({
    required this.ssid,
    required this.controller,
  });

  @override
  State<_WifiConnectDialog> createState() => _WifiConnectDialogState();
}

class _WifiConnectDialogState extends State<_WifiConnectDialog> {
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Connect to ${widget.ssid}'),
      content: TextField(
        controller: _passwordCtrl,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final ok =
                await widget.controller.connect(widget.ssid, _passwordCtrl.text);
            Get.snackbar(
              ok ? 'Berhasil' : 'Gagal',
              ok ? 'Terhubung ke ${widget.ssid}' : 'Gagal menghubungkan ke ${widget.ssid}',
              snackPosition: SnackPosition.bottom,
            );
          },
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
