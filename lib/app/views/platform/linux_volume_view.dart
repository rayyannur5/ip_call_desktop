import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/platform/linux_volume_controller.dart';

class LinuxVolumeView extends GetView<LinuxVolumeController> {
  const LinuxVolumeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Volume Control',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      onPressed: controller.refreshVolumes,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Master Volume
            const Text('Master Volume',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Obx(() => Row(
                  children: [
                    IconButton(
                      onPressed: controller.toggleMasterMute,
                      icon: Icon(
                        controller.isMasterMuted.value
                            ? Icons.volume_off
                            : Icons.volume_up,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: controller.masterVolume.value.toDouble(),
                        max: 100,
                        divisions: 100,
                        label: '${controller.masterVolume.value}%',
                        onChanged: (v) =>
                            controller.setMaster(v.toInt()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${controller.masterVolume.value}%',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )),
            const SizedBox(height: 16),

            // Capture Volume
            const Text('Capture Volume (Mic)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Obx(() => Row(
                  children: [
                    IconButton(
                      onPressed: controller.toggleCaptureMute,
                      icon: Icon(
                        controller.isCaptureMuted.value
                            ? Icons.mic_off
                            : Icons.mic,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: controller.captureVolume.value.toDouble(),
                        max: 100,
                        divisions: 100,
                        label: '${controller.captureVolume.value}%',
                        onChanged: (v) =>
                            controller.setCapture(v.toInt()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${controller.captureVolume.value}%',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
