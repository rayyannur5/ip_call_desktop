import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageService extends GetxService {
  late final GetStorage _box;

  @override
  void onInit() {
    super.onInit();
    _box = GetStorage();
  }

  // --- Server ---
  String get serverHost => _box.read('server_host') ?? '';
  set serverHost(String v) => _box.write('server_host', v);

  // --- MQTT ---
  int get mqttPort => _box.read('mqtt_port') ?? 1883;
  set mqttPort(int v) => _box.write('mqtt_port', v);

  // --- Database ---
  int get dbPort => _box.read('db_port') ?? 3306;
  set dbPort(int v) => _box.write('db_port', v);

  String get dbUsername => _box.read('db_username') ?? '';
  set dbUsername(String v) => _box.write('db_username', v);

  String get dbPassword => _box.read('db_password') ?? '';
  set dbPassword(String v) => _box.write('db_password', v);

  String get dbName => _box.read('db_name') ?? 'ip-call';
  set dbName(String v) => _box.write('db_name', v);

  // --- SIP ---
  String get sipDomain => _box.read('sip_domain') ?? '';
  set sipDomain(String v) => _box.write('sip_domain', v);

  int get sipPort => _box.read('sip_port') ?? 5060;
  set sipPort(int v) => _box.write('sip_port', v);

  String get sipUsername => _box.read('sip_username') ?? '';
  set sipUsername(String v) => _box.write('sip_username', v);

  String get sipPassword => _box.read('sip_password') ?? '';
  set sipPassword(String v) => _box.write('sip_password', v);

  String get sipWsUrl => _box.read('sip_ws_url') ?? '';
  set sipWsUrl(String v) => _box.write('sip_ws_url', v);

  // --- App State (persistent messages/calls) ---
  String? get appState => _box.read('app_state');
  set appState(String? v) => _box.write('app_state', v);

  bool get isConfigured => serverHost.isNotEmpty;
}
