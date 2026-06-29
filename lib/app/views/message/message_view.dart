import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/message_controller.dart';
import '../../controllers/call_controller.dart';
import '../../services/mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Port of Message.jsx — color-coded alert messages
class MessageView extends StatefulWidget {
  const MessageView({super.key});

  @override
  State<MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView> {
  final Map<String, int> _seconds = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ctrl = Get.find<MessageController>();
      if (ctrl.messages.isEmpty) {
        if (_seconds.isNotEmpty) {
          setState(() {
            _seconds.clear();
          });
        }
        return;
      }

      final Map<String, int> newSeconds = {};
      for (final msg in ctrl.messages) {
        final topic = msg['topic'] as String;
        final createdAt = DateTime.parse(msg['created_at']);
        newSeconds[topic] = DateTime.now().difference(createdAt).inSeconds.abs();
      }

      bool changed = _seconds.length != newSeconds.length;
      if (!changed) {
        for (final entry in newSeconds.entries) {
          if (_seconds[entry.key] != entry.value) {
            changed = true;
            break;
          }
        }
      }

      if (changed) {
        setState(() {
          _seconds.clear();
          _seconds.addAll(newSeconds);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _getMessageColor(String message) {
    switch (message) {
      case 'e': return const Color(0xFFEF4444); // red
      case 'i': return const Color(0xFF22C55E); // green
      case 'b': return const Color(0xFF3B82F6); // blue
      case '0': return const Color(0xFF6B7280); // gray
      case 'a': return const Color(0xFFFB923C); // orange
      default: return const Color(0xFFEAB308);  // yellow
    }
  }

  String _getMessageLabel(String message) {
    switch (message) {
      case 'e': return 'DARURAT';
      case 'i': return 'INFUS';
      case 'b': return 'CODE BLUE';
      case '0': return 'PANGGILAN TIDAK TERJAWAB';
      case 'a': return 'PANGGILAN PERAWAT';
      default: return 'TELEPON';
    }
  }

  String _formatTime(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h : $m : $s';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctrl = Get.find<MessageController>();

      if (ctrl.messages.isEmpty) {
        return const Center(
          child: Text(
            'Tidak ada pesan baru',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: ctrl.messages.length,
        itemBuilder: (context, index) {
          final msg = ctrl.messages[index];
          final message = msg['message'] as String;
          final topic = msg['topic'] as String;
          final username = msg['username'] as String? ?? '';
          final seconds = _seconds[topic] ?? 0;
          final color = _getMessageColor(message);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Label and Username in a Column to prevent horizontal overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getMessageLabel(message),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (username.isNotEmpty)
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Stopwatch (not for '0' type)
                if (message != '0') ...[
                  // const Padding(
                  //   padding: EdgeInsets.symmetric(horizontal: 8),
                  //   child: Text('||',
                  //       style: TextStyle(color: Colors.white, fontSize: 18)),
                  // ),
                  Text(
                    _formatTime(seconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],

                // Call button (for 'q' type)
                if (message == 'q')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: () {
                        final id = topic.substring(5);
                        final mqtt = Get.find<MqttService>();
                        mqtt.publish('stop/$id', 'x',
                            qos: MqttQos.atLeastOnce, retain: true);
                        final callCtrl = Get.find<CallController>();
                        callCtrl.call(id, username, username);
                      },
                      icon: const Icon(Icons.call, color: Color(0xFF22C55E)),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                  ),

                // Delete button
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: () {
                      final mqtt = Get.find<MqttService>();
                      mqtt.publish(topic, 'x',
                          qos: MqttQos.atLeastOnce, retain: true);
                      if (topic.contains('call')) {
                        final id = topic.substring(5);
                        mqtt.publish('stop/$id', 'x',
                            qos: MqttQos.atLeastOnce, retain: true);
                      }
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.25),
                      hoverColor: Colors.white.withOpacity(0.35),
                      highlightColor: Colors.white.withOpacity(0.4),
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
