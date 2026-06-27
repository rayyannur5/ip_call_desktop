import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/call_controller.dart';

/// Port of Telpon.jsx — 3 states: ringing, on session, queue
class CallPanelView extends GetView<CallController> {
  const CallPanelView({super.key});

  String _formatTime(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h : $m : $s';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.calls.isEmpty) return const SizedBox.shrink();

      // Access callSeconds to register it as a dependency for Obx
      final _ = controller.callSeconds.length;

      return ListView.builder(
        itemCount: controller.calls.length,
        itemBuilder: (context, index) {
          final call = controller.calls[index];
          final seconds = index < controller.callSeconds.length
              ? controller.callSeconds[index]
              : 0;

          if (index == 0) {
            if (controller.onSession.value) {
              // On Session state
              return _buildCallCard(
                call: call,
                seconds: seconds,
                isSession: true,
              );
            } else {
              // Ringing state
              return _buildCallCard(
                call: call,
                seconds: seconds,
                isSession: false,
              );
            }
          } else {
            // Queue items
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(call['topic']?.substring(5) ?? '',
                      style: const TextStyle(fontSize: 13)),
                  Text(call['name'] ?? '',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            );
          }
        },
      );
    });
  }

  Widget _buildCallCard({
    required Map<String, dynamic> call,
    required int seconds,
    required bool isSession,
  }) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Call icon animation
          Icon(
            isSession ? Icons.phone_in_talk : Icons.phone_callback,
            size: 64,
            color: isSession
                ? const Color(0xFF22C55E)
                : const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            call['name'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Stopwatch
          Text(
            _formatTime(seconds),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),

          // Buttons
          if (isSession && seconds >= 5)
            // Hangup button
            ElevatedButton.icon(
              onPressed: () => controller.hangUp(),
              icon: const Icon(Icons.call_end, color: Colors.red),
              label: const Text('Tutup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
              ),
            )
          else if (!isSession && call['type'] == 'incoming')
            // Answer button
            ElevatedButton.icon(
              onPressed: () => controller.handlerAnswer(call),
              icon: const Icon(Icons.call, color: Color(0xFF22C55E)),
              label: const Text('Jawab'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
              ),
            ),
        ],
      ),
    );
  }
}
