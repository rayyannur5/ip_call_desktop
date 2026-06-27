import 'package:get/get.dart';
import '../../services/platform/linux_volume_service.dart';
import '../../services/storage_service.dart';

class LinuxVolumeController extends GetxController {
  final masterVolume = 100.obs;
  final captureVolume = 100.obs;
  final isMasterMuted = false.obs;
  final isCaptureMuted = false.obs;

  final soundCards = <Map<String, dynamic>>[].obs;
  final selectedCardIndex = (-1).obs;

  @override
  void onInit() {
    super.onInit();
    final storage = Get.find<StorageService>();
    selectedCardIndex.value = storage.soundCardIndex;
    loadSoundCards();
    refreshVolumes();
  }

  Future<void> loadSoundCards() async {
    final service = Get.find<LinuxVolumeService>();
    final cards = await service.getSoundCards();
    soundCards.value = cards;
  }

  Future<void> changeSoundCard(int index) async {
    final storage = Get.find<StorageService>();
    storage.soundCardIndex = index;
    selectedCardIndex.value = index;
    await refreshVolumes();
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
