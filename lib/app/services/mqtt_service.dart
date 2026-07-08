import 'dart:async';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'app_logger.dart';
import 'storage_service.dart';

const _tag = 'MqttService';

class MqttService extends GetxService {
  MqttServerClient? _client;
  final isConnected = false.obs;
  StreamSubscription? _updatesSubscription;

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
    } catch (e, st) {
      logger.e(_tag, 'Connection error', e, st);
      _client?.disconnect();
      return;
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      isConnected.value = true;
      _updatesSubscription?.cancel();
      _updatesSubscription = _client!.updates?.listen(_onMessage, onError: (e) {
        logger.e(_tag, 'Updates stream error', e);
      });
    }
  }

  void _onConnected() {
    logger.i(_tag, 'Connected');
    isConnected.value = true;
    _startPing();
  }

  void _onDisconnected() {
    logger.w(_tag, 'Disconnected');
    isConnected.value = false;
    _stopPing();
  }

  void _onAutoReconnected() {
    logger.i(_tag, 'Auto-reconnected');
    isConnected.value = true;
    _startPing();
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

      logger.d(_tag, '$topic : $message');

      // Dispatch to all registered handlers
      for (final handler in List.from(_messageHandlers)) {
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
    } catch (e, st) {
      logger.e(_tag, 'Subscribe error ($topic)', e, st);
    }
  }

  void unsubscribe(String topic) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    try {
      _client?.unsubscribe(topic);
    } catch (e, st) {
      logger.e(_tag, 'Unsubscribe error ($topic)', e, st);
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
    } catch (e, st) {
      logger.e(_tag, 'Publish error ($topic)', e, st);
    }
  }

  Timer? _pingTimer;

  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        publish('ping', 'p');
      } else {
        _stopPing();
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> disconnect() async {
    _stopPing();
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    _processingTopics.clear();
    _client?.disconnect();
    _client = null;
    isConnected.value = false;
  }

  @override
  void onClose() {
    _stopPing();
    disconnect();
    super.onClose();
  }
}
