import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../controllers/contact_controller.dart';
import '../../../controllers/call_controller.dart';
import '../../../services/storage_service.dart';

/// Port of ListLogTelepon in Kontak.jsx
class HistoryListWidget extends GetView<ContactController> {
  const HistoryListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date picker
        Padding(
          padding: const EdgeInsets.all(8),
          child: Obx(() => GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(controller.currentDate.value) ??
                        DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    controller.setDate(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Get.theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        controller.currentDate.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )),
        ),

        // History list
        Expanded(
          child: Obx(() {
            if (controller.isLoadingHistory.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.histories.isEmpty) {
              return const Center(
                child: Text('Tidak ada data yang ditampilkan'),
              );
            }

            return ListView.builder(
              itemCount: controller.histories.length,
              itemBuilder: (context, index) {
                final h = controller.histories[index];
                final categoryId = h['category_history_id'] ?? '0';

                final theme = Get.theme;
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h['username'] ?? '',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Direction icon
                                Icon(
                                  categoryId == '3'
                                      ? Icons.call_made
                                      : Icons.call_received,
                                  size: 14,
                                  color: categoryId == '2'
                                      ? theme.colorScheme.error
                                      : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${h['category_name'] ?? ''}${h['duration'] != null ? ' | ${h['duration']}' : ''}\n${h['timestamp'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final recordFile = h['record']?.toString();
                          if (recordFile == null || recordFile.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              onPressed: () {
                                final storage = Get.find<StorageService>();
                                final host = storage.serverHost.isEmpty ? 'localhost' : storage.serverHost;
                                String formattedPath = recordFile;
                                if (!formattedPath.startsWith('records/') && !formattedPath.startsWith('/records/')) {
                                  formattedPath = 'records/$formattedPath';
                                }
                                if (formattedPath.startsWith('/')) {
                                  formattedPath = formattedPath.substring(1);
                                }
                                final url = 'http://$host/$formattedPath';

                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => AudioPlayerDialog(
                                    url: url,
                                    title: 'Rekaman Panggilan',
                                    subtitle: '${h['username'] ?? ''} - ${h['timestamp'] ?? ''}',
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.play_arrow,
                                color: Colors.green,
                                size: 24,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.15),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: () {
                          final callCtrl = Get.find<CallController>();
                          callCtrl.call(
                            h['bed_id'] ?? '',
                            h['phone'] ?? '',
                            h['username'] ?? '',
                          );
                        },
                        icon: Icon(Icons.call,
                            color: theme.colorScheme.primary, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class AudioPlayerDialog extends StatefulWidget {
  final String url;
  final String title;
  final String subtitle;

  const AudioPlayerDialog({
    super.key,
    required this.url,
    required this.title,
    required this.subtitle,
  });

  @override
  State<AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<AudioPlayerDialog> {
  late final AudioPlayer _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isDragging = false;
  bool _isCompleted = false;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _compSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _posSub = _player.onPositionChanged.listen((p) {
      if (!_isDragging) {
        setState(() => _position = p);
      }
    });

    _durSub = _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      setState(() {
        _isPlaying = s == PlayerState.playing;
        _isLoading = false;
        if (s == PlayerState.completed) {
          _isCompleted = true;
        }
      });
    });

    _compSub = _player.onPlayerComplete.listen((_) {
      setState(() {
        _position = Duration.zero;
        _isPlaying = false;
        _isCompleted = true;
      });
    });

    try {
      await _player.setSource(UrlSource(widget.url));
      await _player.resume();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memutar rekaman: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _compSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSliderVal = _duration.inMilliseconds.toDouble();
    final currentSliderVal = _position.inMilliseconds.toDouble().clamp(0.0, maxSliderVal);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Loading / Control indicators
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Slider
              Slider(
                value: currentSliderVal,
                max: maxSliderVal > 0 ? maxSliderVal : 1.0,
                onChanged: (val) {
                  setState(() {
                    _isDragging = true;
                    _position = Duration(milliseconds: val.toInt());
                  });
                },
                onChangeEnd: (val) async {
                  final target = Duration(milliseconds: val.toInt());
                  try {
                    if (_isCompleted) {
                      setState(() {
                        _position = target;
                      });
                    } else {
                      await _player.seek(target);
                    }
                  } catch (e) {
                    print('Seek error: $e');
                  }
                  setState(() {
                    _isDragging = false;
                  });
                },
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primaryContainer,
              ),
              // Time stamps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Playback controls
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rewind 5s
                    IconButton(
                      icon: const Icon(Icons.replay_5),
                      onPressed: () async {
                        final target = _position - const Duration(seconds: 5);
                        if (_isCompleted) {
                          setState(() {
                            _position = target < Duration.zero ? Duration.zero : target;
                          });
                        } else {
                          await _player.seek(target < Duration.zero ? Duration.zero : target);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    // Play / Pause
                    IconButton(
                      iconSize: 48,
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () async {
                        if (_isPlaying) {
                          await _player.pause();
                        } else {
                          try {
                            if (_isCompleted || (_position >= _duration && _duration > Duration.zero)) {
                              setState(() => _isCompleted = false);
                              await _player.play(UrlSource(widget.url), position: _position);
                            } else {
                              await _player.resume();
                            }
                          } catch (e) {
                            await _player.play(UrlSource(widget.url), position: _position);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    // Forward 5s
                    IconButton(
                      icon: const Icon(Icons.forward_5),
                      onPressed: () async {
                        final target = _position + const Duration(seconds: 5);
                        if (_isCompleted) {
                          setState(() {
                            _position = target > _duration ? _duration : target;
                          });
                        } else {
                          await _player.seek(target > _duration ? _duration : target);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
