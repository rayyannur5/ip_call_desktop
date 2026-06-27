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

            // Sound Card Selection
            const Text('Sound Card',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Obx(() {
              final cards = controller.soundCards;
              final selectedValue = controller.selectedCardIndex.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedValue,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text('Default Sound Card'),
                      ),
                      ...cards.map((card) {
                        return DropdownMenuItem<int>(
                          value: card['index'] as int,
                          child: Text(
                            '[Card ${card['index']}] ${card['desc']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        controller.changeSoundCard(val);
                      }
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),

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
