import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/home_controller.dart';
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

              // UI / Tampilan Section
              _buildSectionTitle('Tampilan'),
              Obx(() {
                final homeCtrl = Get.find<HomeController>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dark Mode Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.dark_mode, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Dark Mode',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Switch(
                          value: homeCtrl.isDarkMode.value,
                          onChanged: (_) => homeCtrl.toggleDarkMode(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Theme Colors Row
                    const Row(
                      children: [
                        Icon(Icons.palette, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Warna Tema',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Preset Blue
                        _buildColorPreset(homeCtrl, const Color(0xFF2563EB), 'Biru'),
                        // Preset Green
                        _buildColorPreset(homeCtrl, const Color(0xFF16A34A), 'Hijau'),
                        // Preset Orange/Red
                        _buildColorPreset(homeCtrl, const Color(0xFFEA580C), 'Oranye'),
                        // Preset Purple
                        _buildColorPreset(homeCtrl, const Color(0xFF9333EA), 'Ungu'),
                        
                        // Custom Color Button
                        OutlinedButton.icon(
                          onPressed: () => _showColorPickerDialog(context, homeCtrl),
                          icon: const Icon(Icons.color_lens, size: 16),
                          label: const Text('Custom'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2037),
                          );
                          if (date != null) {
                            final ok = await controller.setSystemDateOnly(date);
                            Get.snackbar(
                              ok ? 'Berhasil' : 'Gagal',
                              ok ? 'Tanggal sistem berhasil diubah' : 'Gagal mengubah tanggal (butuh akses root)',
                              snackPosition: SnackPosition.bottom,
                            );
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Set Date'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          if (context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(now),
                            );
                            if (time != null) {
                              final ok = await controller.setSystemTimeOnly(time);
                              Get.snackbar(
                                ok ? 'Berhasil' : 'Gagal',
                                ok ? 'Jam sistem berhasil diubah' : 'Gagal mengubah jam (butuh akses root)',
                                snackPosition: SnackPosition.bottom,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: const Text('Set Time'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: const Text('Reset Pesan & MQTT?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    controller.resetData();
                                    Navigator.of(context).pop(); // Tutup modal setting
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white),
                                  child: const Text('Ya, Reset Data'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Reset Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: const Text('Reboot Perangkat?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    controller.rebootDevice();
                                    Navigator.of(context).pop(); // Tutup modal setting
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white),
                                  child: const Text('Ya, Reboot'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Reboot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                        ),
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
                    const SizedBox(height: 16),

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

  Widget _buildColorPreset(HomeController homeCtrl, Color color, String name) {
    final isSelected = homeCtrl.themeColor.value.value == color.value;
    return InkWell(
      onTap: () => homeCtrl.changeThemeColor(color),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isSelected ? 0.2 : 0.05),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (Get.isDarkMode ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context, HomeController homeCtrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SliderColorPickerDialog(
          initialColor: homeCtrl.themeColor.value,
          onColorSelected: (Color selectedColor) {
            homeCtrl.changeThemeColor(selectedColor);
          },
        );
      },
    );
  }
}

class SliderColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const SliderColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<SliderColorPickerDialog> createState() => _SliderColorPickerDialogState();
}

class _SliderColorPickerDialogState extends State<SliderColorPickerDialog> {
  late double _red;
  late double _green;
  late double _blue;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final color = widget.initialColor;
    _red = color.red.toDouble();
    _green = color.green.toDouble();
    _blue = color.blue.toDouble();
    _hexController = TextEditingController(text: _currentColorToHex());
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _currentColorToHex() {
    final r = _red.round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = _green.round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = _blue.round().toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$r$g$b';
  }

  void _onHexChanged(String val) {
    String cleanHex = val.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final colorInt = int.tryParse(cleanHex, radix: 16);
      if (colorInt != null) {
        final color = Color(colorInt | 0xFF000000);
        setState(() {
          _red = color.red.toDouble();
          _green = color.green.toDouble();
          _blue = color.blue.toDouble();
        });
      }
    }
  }

  Color get _currentColor {
    return Color.fromARGB(255, _red.round(), _green.round(), _blue.round());
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final luminance = currentColor.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return AlertDialog(
      title: const Text('Pilih Warna Tema'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview Color Box
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hex Code Input
              Row(
                children: [
                  const Text('Hex Code: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _hexController,
                        onChanged: _onHexChanged,
                        decoration: InputDecoration(
                          hintText: '#RRGGBB',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // RED (Merah)
              Row(
                children: [
                  const Text('Merah (Red)', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${_red.round()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.red,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.2),
                      trackHeight: 12,
                    ),
                    child: Slider(
                      value: _red,
                      min: 0.0,
                      max: 255.0,
                      onChanged: (val) {
                        setState(() {
                          _red = val;
                          _hexController.text = _currentColorToHex();
                        });
                      },
                    ),
                  ),
                ],
              ),

              // GREEN (Hijau)
              Row(
                children: [
                  const Text('Hijau (Green)', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${_green.round()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.green,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.2),
                      trackHeight: 12,
                    ),
                    child: Slider(
                      value: _green,
                      min: 0.0,
                      max: 255.0,
                      onChanged: (val) {
                        setState(() {
                          _green = val;
                          _hexController.text = _currentColorToHex();
                        });
                      },
                    ),
                  ),
                ],
              ),

              // BLUE (Biru)
              Row(
                children: [
                  const Text('Biru (Blue)', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${_blue.round()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.blue,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.2),
                      trackHeight: 12,
                    ),
                    child: Slider(
                      value: _blue,
                      min: 0.0,
                      max: 255.0,
                      onChanged: (val) {
                        setState(() {
                          _blue = val;
                          _hexController.text = _currentColorToHex();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorSelected(currentColor);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
