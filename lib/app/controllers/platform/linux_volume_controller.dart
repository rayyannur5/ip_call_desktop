import 'package:get/get.dart';
import '../../services/platform/linux_volume_service.dart';

class LinuxVolumeController extends GetxController {
  final masterVolume = 100.obs;
  final captureVolume = 100.obs;
  final isMasterMuted = false.obs;
  final isCaptureMuted = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshVolumes();
  }

  Future<void> refreshVolumes() async {
    final service = Get.find<LinuxVolumeService>();
    final master = await service.getMasterVolume();
    masterVolume.value = master['volume'] as int;
    isMasterMuted.value = master['muted'] as bool;

    final capture = await service.getCaptureVolume();
    captureVolume.value = capture['volume'] as int;
    isCaptureMuted.value = capture['muted'] as bool;
  }

  Future<void> setMaster(int percent) async {
    final service = Get.find<LinuxVolumeService>();
    await service.setMasterVolume(percent);
    masterVolume.value = percent;
  }

  Future<void> setCapture(int percent) async {
    final service = Get.find<LinuxVolumeService>();
    await service.setCaptureVolume(percent);
    captureVolume.value = percent;
  }

  Future<void> toggleMasterMute() async {
    final service = Get.find<LinuxVolumeService>();
    await service.toggleMasterMute();
    await refreshVolumes();
  }

  Future<void> toggleCaptureMute() async {
    final service = Get.find<LinuxVolumeService>();
    await service.toggleCaptureMute();
    await refreshVolumes();
  }
}
