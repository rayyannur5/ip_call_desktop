import 'dart:async';
import 'package:get/get.dart';
import '../../services/app_logger.dart';
import '../../services/platform/linux_volume_service.dart';
import '../../services/storage_service.dart';

const _tag = 'LinuxVolumeController';

class LinuxVolumeController extends GetxController {
  final masterVolume = 100.obs;
  final captureVolume = 100.obs;
  final isMasterMuted = false.obs;
  final isCaptureMuted = false.obs;

  final soundCards = <Map<String, dynamic>>[].obs;
  final selectedCardIndex = (-1).obs;

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  void onInit() {
    super.onInit();
    final storage = Get.find<StorageService>();
    selectedCardIndex.value = storage.soundCardIndex;
    loadSoundCards();
    refreshVolumes();
    _startSyncTimer();
  }

  @override
  void onClose() {
    _syncTimer?.cancel();
    super.onClose();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _reconcile();
    _syncTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _reconcile());
  }

  /// Compares live system audio state against the values persisted in
  /// [StorageService] every tick; on mismatch the stored value wins and is
  /// re-applied to the system. On first run (no stored state yet) the
  /// current system state is captured into storage instead.
  Future<void> _reconcile() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final service = Get.find<LinuxVolumeService>();
      final storage = Get.find<StorageService>();

      final cards = await service.getSoundCards();
      int? liveDefaultIndex;
      for (final card in cards) {
        if (card['isDefault'] == true) {
          liveDefaultIndex = card['index'] as int;
          break;
        }
      }
      if (storage.soundCardIndex == -1) {
        if (liveDefaultIndex != null) storage.soundCardIndex = liveDefaultIndex;
      } else if (liveDefaultIndex != null &&
          liveDefaultIndex != storage.soundCardIndex) {
        await service.setDefaultOutput(storage.soundCardIndex);
      }
      selectedCardIndex.value = storage.soundCardIndex;
      soundCards.value = cards;

      final master = await service.getMasterVolume();
      final capture = await service.getCaptureVolume();

      if (!storage.hasAudioState) {
        storage.masterVolume = master['volume'] as int;
        storage.isMasterMuted = master['muted'] as bool;
        storage.captureVolume = capture['volume'] as int;
        storage.isCaptureMuted = capture['muted'] as bool;
        storage.hasAudioState = true;
      } else {
        if ((master['volume'] as int) != storage.masterVolume) {
          await service.setMasterVolume(storage.masterVolume);
        }
        if ((master['muted'] as bool) != storage.isMasterMuted) {
          await service.setMasterMute(storage.isMasterMuted);
        }
        if ((capture['volume'] as int) != storage.captureVolume) {
          await service.setCaptureVolume(storage.captureVolume);
        }
        if ((capture['muted'] as bool) != storage.isCaptureMuted) {
          await service.setCaptureMute(storage.isCaptureMuted);
        }
      }

      masterVolume.value = storage.masterVolume;
      isMasterMuted.value = storage.isMasterMuted;
      captureVolume.value = storage.captureVolume;
      isCaptureMuted.value = storage.isCaptureMuted;
    } catch (e, st) {
      logger.e(_tag, 'Audio state reconcile error', e, st);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> loadSoundCards() async {
    final service = Get.find<LinuxVolumeService>();
    final cards = await service.getSoundCards();
    soundCards.value = cards;
    for (final card in cards) {
      if (card['isDefault'] == true) {
        selectedCardIndex.value = card['index'] as int;
        break;
      }
    }
  }

  Future<void> changeSoundCard(int index) async {
    final service = Get.find<LinuxVolumeService>();
    final storage = Get.find<StorageService>();
    await service.setDefaultOutput(index);
    storage.soundCardIndex = index;
    selectedCardIndex.value = index;
    await refreshVolumes();
  }

  Future<void> refreshVolumes() async {
    await loadSoundCards();
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
    final storage = Get.find<StorageService>();
    await service.setMasterVolume(percent);
    masterVolume.value = percent;
    storage.masterVolume = percent;
  }

  Future<void> setCapture(int percent) async {
    final service = Get.find<LinuxVolumeService>();
    final storage = Get.find<StorageService>();
    await service.setCaptureVolume(percent);
    captureVolume.value = percent;
    storage.captureVolume = percent;
  }

  Future<void> toggleMasterMute() async {
    final service = Get.find<LinuxVolumeService>();
    final storage = Get.find<StorageService>();
    await service.toggleMasterMute();
    await refreshVolumes();
    storage.isMasterMuted = isMasterMuted.value;
  }

  Future<void> toggleCaptureMute() async {
    final service = Get.find<LinuxVolumeService>();
    final storage = Get.find<StorageService>();
    await service.toggleCaptureMute();
    await refreshVolumes();
    storage.isCaptureMuted = isCaptureMuted.value;
  }
}
