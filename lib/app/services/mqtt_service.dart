import 'dart:async';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'storage_service.dart';

class MqttService extends GetxService {
  MqttServerClient? _client;
  final isConnected = false.obs;

  /// Deduplication set — same as processingTopics in App.jsx
  final Set<String> _processingTopics = {};

  /// Callbacks for message handling — controllers register their handlers
  final List<void Function(String topic, String message)> _messageHandlers = [];

  void addMessageHandler(void Function(String topic, String message) handler) {
    _messageHandlers.add(handler);
  }

  void removeMessageHandler(
      void Function(String topic, String message) handler) {
    _messageHandlers.remove(handler);
  }

  Future<void> connect() async {
    final storage = Get.find<StorageService>();
    if (storage.serverHost.isEmpty) return;

    try {
      await disconnect();
    } catch (_) {}

    final clientId = 'flutter_nursecall_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient(storage.serverHost, clientId);
    _client!.port = storage.mqttPort;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnected = _onAutoReconnected;
    _client!.logging(on: false);

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    _client!.connectionMessage = connMsg;

    try {
      await _client!.connect();
    } catch (e) {
      print('MQTT Connection Error: $e');
      _client?.disconnect();
      return;
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      isConnected.value = true;
      _client!.updates?.listen(_onMessage, onError: (e) {
        print('MQTT Updates stream error: $e');
      });
    }
  }

  void _onConnected() {
    print('MQTT CONNECTED');
    isConnected.value = true;
  }

  void _onDisconnected() {
    print('MQTT DISCONNECTED');
    isConnected.value = false;
  }

  void _onAutoReconnected() {
    print('MQTT AUTO RECONNECTED');
    isConnected.value = true;
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final payload = msg.payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message);

      // Deduplication — same as processingTopics Set in App.jsx (line 79-84)
      final key = '$topic-$message';
      if (_processingTopics.contains(key)) continue;
      _processingTopics.add(key);
      Future.delayed(const Duration(seconds: 1), () {
        _processingTopics.remove(key);
      });

      print('$topic : $message');

      // Dispatch to all registered handlers
      for (final handler in _messageHandlers) {
        handler(topic, message);
      }
    }
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    try {
      _client?.subscribe(topic, qos);
    } catch (e) {
      print('MQTT subscribe error: $e');
    }
  }

  void unsubscribe(String topic) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    try {
      _client?.unsubscribe(topic);
    } catch (e) {
      print('MQTT unsubscribe error: $e');
    }
  }

  void publish(String topic, String message,
      {MqttQos qos = MqttQos.atMostOnce, bool retain = false}) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, qos, builder.payload!, retain: retain);
    } catch (e) {
      print('MQTT publish error: $e');
    }
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
    isConnected.value = false;
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
