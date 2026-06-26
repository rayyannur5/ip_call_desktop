# Migrasi Nurse Call: Vite JS → Flutter Desktop (v2)

Migrasi aplikasi Nurse Call dari React/Vite (`/Users/user/Projects/ip-call-app`) ke Flutter Desktop (`/Users/user/Projects/ip_call_desktop`) dengan arsitektur GetX, MQTT, SIP UA, dan **direct MySQL** (tanpa API layer).

## Perubahan dari Plan v1

> [!IMPORTANT]
> **API dihapus → Direct MySQL**: Semua data diambil langsung dari database MySQL menggunakan package `mysql_client`. Tidak ada lagi HTTP API call ke PHP backend. Semua query yang sebelumnya dilakukan oleh PHP endpoint sekarang dijalankan langsung oleh Flutter app.

> [!IMPORTANT]
> **Model classes dihapus**: Tidak perlu Dart model. Data dari database dihandle langsung sebagai `Map<String, dynamic>` dari query results.

> [!IMPORTANT]
> **Audio dinamis**: File audio dari tabel `mastersound` akan didownload dari server ke folder lokal. Path di DB tetap dipakai sebagai referensi download.

---

## Open Questions

> [!IMPORTANT]
> 1. **SIP Server Config**: SIP domain, port, dan credential akan configurable via UI (settings). Apakah SIP server sudah ready atau perlu setup juga?
> 2. **Audio Download Path**: File audio dari `mastersound.source` (contoh: `static/ruang.mp3`) — dari mana didownload? Apakah ada HTTP file server yang serve folder tersebut? Atau audio filenya diambil dari path di server MySQL langsung?
> 3. **Database Host**: Apakah MySQL server sama dengan MQTT broker (1 IP untuk semua)?

---

## Database Schema (dari [ip-call.sql](file:///Users/user/Projects/ip_call_desktop/ip-call.sql))

Tabel yang digunakan oleh app:

| Tabel | Kegunaan |
|---|---|
| `bed` | Data bed/device (id, room_id, username, vol, mic, tw, mode, phone, bypass, cable) |
| `room` | Data ruangan (id, type, name, bypass) |
| `toilet` | Data toilet device (id, room_id, username, bypass) |
| `mastersound` | Audio dinamis (name, source path) |
| `utils` | Konfigurasi app (interval_speaks, timeout_call, interval_update_status, dll) |
| `history` | Riwayat panggilan (bed_id, category_history_id, duration, record, timestamp) |
| `category_history` | Kategori riwayat (1=Masuk, 2=Tidak Terjawab, 3=Keluar) |
| `log` | Log alert (category_log_id, device_id, time, nurse_presence, timestamp) |
| `category_log` | Kategori log (1=Darurat, 2=Telepon, 3=Code Blue, 4=Infus, 5=Perawat) |

---

## Project Structure

```
lib/
├── main.dart
├── app/
│   ├── bindings/
│   │   └── app_binding.dart
│   ├── routes/
│   │   ├── app_pages.dart
│   │   └── app_routes.dart
│   ├── services/
│   │   ├── database_service.dart         # Direct MySQL queries
│   │   ├── mqtt_service.dart             # MQTT connection & message handling
│   │   ├── sip_service.dart              # SIP UA registration & call handling
│   │   ├── audio_service.dart            # Sound playback & speak system
│   │   ├── storage_service.dart          # GetStorage (server host, settings)
│   │   └── platform/
│   │       ├── linux_wifi_service.dart    # WiFi via nmcli (Linux only)
│   │       └── linux_volume_service.dart  # Volume via amixer (Linux only)
│   ├── controllers/
│   │   ├── home_controller.dart          # Main app state & orchestration
│   │   ├── call_controller.dart          # Call state management
│   │   ├── message_controller.dart       # Nurse call messages state
│   │   ├── device_controller.dart        # Device list & status
│   │   ├── contact_controller.dart       # Contact list & search
│   │   ├── log_controller.dart           # Log viewer state
│   │   ├── settings_controller.dart      # Server host & settings
│   │   └── platform/
│   │       ├── linux_wifi_controller.dart
│   │       └── linux_volume_controller.dart
│   └── views/
│       ├── home/
│       │   ├── home_view.dart
│       │   └── widgets/
│       │       ├── app_bar_widget.dart
│       │       └── clock_widget.dart
│       ├── call/
│       │   └── call_panel_view.dart
│       ├── message/
│       │   └── message_view.dart
│       ├── contact/
│       │   ├── contact_view.dart
│       │   └── widgets/
│       │       ├── contact_list_widget.dart
│       │       └── history_list_widget.dart
│       ├── device/
│       │   └── device_view.dart
│       ├── log/
│       │   └── log_view.dart
│       ├── settings/
│       │   └── settings_view.dart
│       └── platform/
│           ├── linux_wifi_view.dart
│           └── linux_volume_view.dart
```

---

## Proposed Changes

### 1. Dependencies & Configuration

#### [MODIFY] [pubspec.yaml](file:///Users/user/Projects/ip_call_desktop/pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management & Routing
  get: ^5.0.0-release-candidate-9.3.3
  get_storage: ^2.1.1
  
  # MQTT
  mqtt_client: ^10.11.11
  
  # SIP
  sip_ua: ^1.1.0
  
  # Database (direct MySQL, tanpa API)
  mysql_client: ^0.0.27
  
  # Audio
  audioplayers: ^6.1.0
  
  # HTTP (hanya untuk download audio files)
  http: ^1.2.0
  
  # Utilities
  intl: ^0.19.0              # Date formatting
  process_run: ^1.2.0        # Linux process exec (nmcli, amixer)
  path_provider: ^2.1.0      # Local audio cache directory
  path: ^1.9.0
```

Add assets (hanya built-in sounds, bukan dynamic sounds):
```yaml
flutter:
  assets:
    - assets/sounds/        # ringing.ogg, rejected.mp3, opening.mp3
    - assets/speaks/        # satu.ogg, dua.ogg, ..., darurat.ogg, A.mp3, dll
    - assets/icons/         # bg-20.png, logo, on.svg, off.svg
```

---

### 2. Services

#### [NEW] [storage_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/storage_service.dart)

GetStorage wrapper — semua config persistent, **tidak hardcoded**:

```
Stored Keys:
├── server_host        (String) — IP/hostname server
├── mqtt_port          (int, default: 1883)
├── db_port            (int, default: 3306)
├── db_username        (String)
├── db_password        (String)
├── db_name            (String, default: "ip-call")
├── sip_domain         (String)
├── sip_port           (int, default: 5060)
├── sip_username       (String)
├── sip_password       (String)
├── sip_ws_url         (String) — WebSocket URL for SIP
└── app_state          (String/JSON) — persistent messages/calls state
```

- Diinisialisasi di `main.dart` sebelum `runApp`
- Getter/setter methods
- Jika `server_host` kosong → redirect ke Settings

---

#### [NEW] [database_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/database_service.dart)

**Menggantikan seluruh API layer**. Koneksi langsung ke MariaDB/MySQL via `mysql_client`.

```dart
class DatabaseService extends GetxService {
  MySQLConnection? _conn;
  
  Future<void> connect() async {
    final storage = Get.find<StorageService>();
    _conn = await MySQLConnection.createConnection(
      host: storage.serverHost,
      port: storage.dbPort,
      userName: storage.dbUsername,
      password: storage.dbPassword,
      databaseName: storage.dbName,
    );
    await _conn!.connect();
  }
}
```

**Query mapping dari semua PHP endpoint → SQL langsung:**

| PHP Endpoint Lama | SQL Query di `database_service.dart` |
|---|---|
| `GET /bed/get_all.php` | `SELECT * FROM bed` |
| `GET /bed/get_one.php?id=X` | `SELECT * FROM bed WHERE id = :id` |
| `GET /device.php` | `SELECT r.*, b.* FROM room r JOIN bed b ON b.room_id = r.id` + `SELECT t.* FROM toilet t` (grouped by room) |
| `GET /device2w.php` | `SELECT r.*, b.* FROM room r JOIN bed b ON b.room_id = r.id WHERE b.tw = 1` (grouped by room) |
| `GET /toilet/get.php?id=X` | `SELECT * FROM toilet WHERE id = :id` |
| `GET /room/get_one.php?id=X` | `SELECT * FROM room WHERE id = :id` |
| `GET /utils.php` | `SELECT * FROM utils` |
| `GET /sounds.php` | `SELECT * FROM mastersound` |
| `GET /history/get.php?date=X` | `SELECT h.*, ch.name, b.username, b.phone FROM history h JOIN category_history ch ON h.category_history_id = ch.id LEFT JOIN bed b ON b.id = h.bed_id WHERE DATE(h.timestamp) = :date ORDER BY h.timestamp DESC` |
| `GET /history/create.php` | `INSERT INTO history (bed_id, category_history_id, duration) VALUES (:bed_id, :cat, :dur)` |
| `GET /log/get/index.php?date=X` | `SELECT l.*, cl.name, COALESCE(b.username, t.username) as username FROM log l JOIN category_log cl ON l.category_log_id = cl.id LEFT JOIN bed b ON b.id = l.device_id LEFT JOIN toilet t ON t.id = l.device_id WHERE DATE(l.timestamp) = :date ORDER BY l.timestamp DESC` |
| `GET /log/{type}/create.php` | `INSERT INTO log (category_log_id, device_id, time, nurse_presence) VALUES (:cat, :dev, :time, :np)` |

Category mapping (sama dengan `LogController.php`):
```
darurat → category_log_id = 1
call    → category_log_id = 2
blue    → category_log_id = 3
infus   → category_log_id = 4
assist  → category_log_id = 5
```

Methods:
- `getAllBeds()` → `List<Map<String, dynamic>>`
- `getBedById(String id)` → `Map<String, dynamic>?`
- `getToiletById(String id)` → `Map<String, dynamic>?`
- `getRoomById(int id)` → `Map<String, dynamic>?`
- `getDevicesGroupedByRoom()` → `List<Map>` (beds + toilets grouped by room, termasuk room type device)
- `getDevices2Way()` → `List<Map>` (hanya beds dengan tw=1, grouped by room)
- `getUtils()` → `Map<String, double>`
- `getMasterSounds()` → `List<Map<String, dynamic>>`
- `getHistoryByDate(String date)` → `List<Map>`
- `createHistory(String bedId, int category, {String? duration})` → `void`
- `getLogsByDate(String date)` → `List<Map>`
- `createLog(int categoryId, String deviceId, int time, int nursePresence)` → `void`

---

#### [NEW] [mqtt_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/mqtt_service.dart)

**Port 1-to-1 dari semua MQTT handler — logika 100% sama**

Connect via native TCP (bukan WebSocket):
```dart
final client = MqttServerClient(serverHost, 'flutter_nursecall');
client.port = mqttPort; // default 1883
```

Core logic yang di-preserve (sama persis dengan [App.jsx](file:///Users/user/Projects/ip-call-app/src/App.jsx)):
- Deduplication via `processingTopics` Set dengan 1 detik timeout (line 79-84)
- Message routing per topic — toilet, bed (check mode via DB), infus, blue, assist, call, panggil, tidakterjawab, room, internal, aktif
- Subscribe logic dari [Devices.jsx](file:///Users/user/Projects/ip-call-app/src/Devices.jsx) constructor (line 56-88):
  - Load devices dari DB
  - Subscribe: `call/{id}`, `tidakterjawab/{id}`, `bed/{id}`, `infus/{id}`, `blue/{id}`, `assist/{id}` per bed
  - Subscribe: `toilet/{id}` per toilet
  - Subscribe: `{room_id}` per room-type device
  - Subscribe: `panggil`, `internal`, `aktif`
- Periodic re-subscribe setiap 30 detik (line 18-54)
- Publish methods: `publish(topic, message, {qos, retain})`

**Perbedaan**: `getBedById()` sekarang query DB langsung, bukan API call.

---

#### [NEW] [sip_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/sip_service.dart)

**BARU — menggantikan MQTT `panggil`/`tutup` untuk audio call**

- Register ke SIP server menggunakan `sip_ua`
- Config dari GetStorage: `sipDomain`, `sipPort`, `sipUsername`, `sipPassword`, `sipWsUrl`
- `makeCall(String number)` — buat panggilan keluar
- `answerCall()` — jawab panggilan masuk
- `hangUp()` — tutup panggilan aktif
- Event callbacks ke `CallController`

**Mapping dari logika lama:**

| Aksi Lama (MQTT) | Aksi Baru (SIP UA) |
|---|---|
| `client.publish("panggil", number)` | `sipService.makeCall(number)` |
| `client.publish("tutup", "1")` | `sipService.hangUp()` |
| `topic.includes('panggil') && message == 1` | `sipService.onCallAccepted` callback |

> [!NOTE]
> MQTT publish ke `call/{id}`, `stop/{id}`, `tidakterjawab/{id}` dll **tetap dipertahankan** — ini untuk kontrol hardware device, bukan audio call.

---

#### [NEW] [audio_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/audio_service.dart)

**Port dari [speak.js](file:///Users/user/Projects/ip-call-app/src/speak.js) — 100% logika sama**

Built-in sounds (dari assets/):
- speaks: satu.ogg, dua.ogg, ..., darurat.ogg, infus.ogg, blue.ogg, telepon.ogg, tidak_terjawab.ogg, perawat.ogg, A.mp3-L.mp3, belas.ogg, puluh.ogg, sebelas.ogg, sepuluh.ogg
- sounds: ringing.ogg, rejected.mp3, opening.mp3

Dynamic sounds (dari DB `mastersound` tabel):
- Saat app start, query `SELECT * FROM mastersound`
- Download file dari server: `http://{serverHost}/ip-call/{source}` ke folder lokal cache
- Jika `source` = null → skip
- Map nama (lowercase) ke file path lokal

Methods:
- `speak(String str, String msg, String username)` — sequential playback dengan `playSound()` + sleep antar kata
- `numberToText(int num)` — angka → teks Indonesia
- `playSound(AudioPlayer player)` → Play dengan Completer, fallback timeout
- `publishDotmatrix(fixDotStr)` — publish ke MQTT topic `dotmatrix`
- `playRinging()`, `stopRinging()`, `playRejected()`

---

#### [NEW] [linux_wifi_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/platform/linux_wifi_service.dart)

**Fitur baru — Linux only** (pakai `process_run`)

- `scanWifi()` → `sudo nmcli device wifi list` → parse output ke List<Map>
  - Fields: SSID, SIGNAL, SECURITY, IN-USE
- `connectWifi(String ssid, String password)` → `sudo nmcli device wifi connect "$ssid" password "$password"`
- `getActiveConnection()` → `nmcli connection show --active` → parse
- `disconnect(String connectionName)` → `nmcli connection down "$connectionName"`
- Guard: check `Platform.isLinux` sebelum exec

---

#### [NEW] [linux_volume_service.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/services/platform/linux_volume_service.dart)

**Fitur baru — Linux only** (pakai `process_run`)

- `getMasterVolume()` → parse output dari `amixer get Master`
  - Parse pattern: `[XX%]` dan `[on]`/`[off]`
  - Return: `{volume: int, muted: bool}`
- `setMasterVolume(int percent)` → `amixer set Master ${percent}%`
- `getCaptureVolume()` → parse `amixer get Capture`
- `setCaptureVolume(int percent)` → `amixer set Capture ${percent}%`
- `toggleMasterMute()` → `amixer set Master toggle`
- `toggleCaptureMute()` → `amixer set Capture toggle`

---

### 3. Controllers

#### [NEW] [home_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/home_controller.dart)

Main orchestrator. Mapping dari [App.jsx](file:///Users/user/Projects/ip-call-app/src/App.jsx) state:

```dart
class HomeController extends GetxController {
  final onDevices = false.obs;     // toggle device panel
  final onContacts = true.obs;     // toggle contact panel
  final serverState = false.obs;   // server heartbeat
  final logKey = 0.obs;            // force log refresh
  Timer? serverTimeout;
  
  int intervalSpeaks = 7000;       // dari utils DB
  int timeoutCall = 60000;         // dari utils DB
  int intervalUpdateStatus = 10000; // dari utils DB
}
```

`onInit()`:
- Load utils config dari DB (`DatabaseService.getUtils()`)
- Set `intervalSpeaks`, `timeoutCall`, `intervalUpdateStatus`

---

#### [NEW] [call_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/call_controller.dart)

**Port dari call logic di [App.jsx](file:///Users/user/Projects/ip-call-app/src/App.jsx) line 247-520 + [Telpon.jsx](file:///Users/user/Projects/ip-call-app/src/Telpon.jsx)**

```dart
class CallController extends GetxController {
  final calls = <Map<String, dynamic>>[].obs;
  final onSession = false.obs;
  Timer? timeout;
  Timer? timeoutSipError;
}
```

Methods (logika sama persis):
- `call(String id, String number, String name)`:
  1. `sipService.makeCall(number)` (SIP)
  2. `mqtt.publish("call/$id", "a", qos:1, retain:true)` (MQTT)
  3. Start `timeoutSipError` 15 detik
  4. Add ke `calls` list

- `hangUp()`:
  1. `sipService.hangUp()` (SIP)
  2. Hitung durasi, publish MQTT `call/{id}` → "h"
  3. Jika state=0 (incoming not answered): publish `stop/{id}` → "m", add message "w"
  4. Create history via `DatabaseService.createHistory()`
  5. Remove dari `calls`

- `handlerAnswer(Map call)`:
  1. `sipService.makeCall(call['phone'])` (SIP)
  2. `mqtt.publish(call['topic'], "a", qos:1, retain:true)` (MQTT)
  3. Start `timeoutSipError` 15 detik

- `newCall()`: manage ringing + timeout (mapping line 286-321)
- Auto hangup jika durasi > 600 detik (dari Telpon.jsx line 20-22)

---

#### [NEW] [message_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/message_controller.dart)

**Port dari message logic di [App.jsx](file:///Users/user/Projects/ip-call-app/src/App.jsx) line 323-453**

```dart
class MessageController extends GetxController {
  final messages = <Map<String, dynamic>>[].obs;
  Timer? speakInterval;
  int indexInterval = 0;
  int counterIndexInterval = 0;
}
```

Methods:
- `addMessage(String topic, String message, String name)`:
  - Cek duplikat by topic
  - Jika name kosong: resolve via DB query (toilet/bed/room)
  - Add ke list, persist ke GetStorage

- `deleteMessage(String topic, String message, String type)`:
  - Hitung durasi (seconds)
  - Jika type != "": create log via `DatabaseService.createLog()` — mapping type → category_log_id
  - Remove dari list, increment logKey

- `getCategoryMessage(int index)` — mapping: e→darurat, w→telepon, b→blue, 0→tidak_terjawab, a→perawat, i→infus

- `newMessage()` — speak interval logic:
  - Jika ada messages dan belum ada interval → start speak + setInterval
  - Rotate: 3x per message, lalu pindah ke next message
  - Stop jika onSession aktif
  - Clear interval jika messages kosong

- Persistent state via GetStorage (replace localStorage dari line 228-231)

---

#### [NEW] [device_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/device_controller.dart)

**Port dari [Devices.jsx](file:///Users/user/Projects/ip-call-app/src/Devices.jsx) + [CountDeviceOff.jsx](file:///Users/user/Projects/ip-call-app/src/CountDeviceOff.jsx)**

```dart
class DeviceController extends GetxController {
  final devices = <Map<String, dynamic>>[].obs;  // grouped by room
  int intervalUpdateStatus = 10000;
}
```

- `onInit()`:
  1. Load devices dari DB (`getDevicesGroupedByRoom()`)
  2. Set bypass → active
  3. Subscribe semua topic per device
  4. Start 30s periodic re-subscribe

- MQTT `aktif` handler: set device active, start timeout per device
- MQTT topic handlers: update device message state (toilet/infus/blue/bed)
- `countDevices()` → `{aktif: int, nonaktif: int}`
- `checkActiveForParent(room)` / `checkMessageForParent(room)`

---

#### [NEW] [contact_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/contact_controller.dart)

**Port dari [Kontak.jsx](file:///Users/user/Projects/ip-call-app/src/Kontak.jsx) + [KontakList.jsx](file:///Users/user/Projects/ip-call-app/src/KontakList.jsx)**

- `isKontak` (RxBool) — tab switch
- `beds` / `bedsFiltered` — dari DB `SELECT * FROM bed`
- `devices2w` — dari DB (beds dengan tw=1, grouped by room) + active tracking via MQTT `aktif`
- `histories` — dari DB `SELECT ... FROM history WHERE date = :date`
- `search(String query)` — filter by username (lowercase match)
- `pengelompokkan()` — group beds by room_id, exclude rooms where all beds have tw=0
- `loadHistory(String date)` — query history by date

---

#### [NEW] [log_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/log_controller.dart)

**Port dari [Log.jsx](file:///Users/user/Projects/ip-call-app/src/Log.jsx)**

- `logs` (RxList)
- `currentDate` (Rx<DateTime>)
- `loadLogs()` — query from DB
- `getWaktuTerbilang(int seconds)` — format duration (jam/menit/detik in Indonesian)

---

#### [NEW] [settings_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/settings_controller.dart)

**Fitur baru — semua config di satu tempat**

Fields (dari GetStorage):
```
Server:
├── serverHost (TextEditingController)
├── mqttPort (TextEditingController, default: 1883)
│
Database:
├── dbPort (TextEditingController, default: 3306)
├── dbUsername (TextEditingController)
├── dbPassword (TextEditingController)
├── dbName (TextEditingController, default: "ip-call")
│
SIP:
├── sipDomain (TextEditingController)
├── sipPort (TextEditingController, default: 5060)
├── sipUsername (TextEditingController)
├── sipPassword (TextEditingController)
└── sipWsUrl (TextEditingController)
```

Methods:
- `save()` → write ke GetStorage, reconnect MQTT + DB + SIP
- `testConnection()` → test DB connection
- Validation (required fields)

---

#### [NEW] [linux_wifi_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/platform/linux_wifi_controller.dart)

- `wifiList` (RxList) — scanned networks
- `activeConnection` (RxString)
- `isScanning` (RxBool)
- `scan()`, `connect(ssid, password)`, `disconnect()`

#### [NEW] [linux_volume_controller.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/controllers/platform/linux_volume_controller.dart)

- `masterVolume` (RxInt), `captureVolume` (RxInt)
- `isMasterMuted` (RxBool), `isCaptureMuted` (RxBool)
- `setMaster(int)`, `setCapture(int)`, `toggleMasterMute()`, `toggleCaptureMute()`
- `refreshVolumes()` — read current state on init & after changes

---

### 4. Views

#### [NEW] [home_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/home/home_view.dart)

**Port dari layout di [App.jsx](file:///Users/user/Projects/ip-call-app/src/App.jsx) render() line 561-683**

```
┌─────────────────────────────────────────────────────────┐
│ AppBar (logo, server●, [X Terhubung][Y Terputus], ⚙, 🕐) │
├──────┬───────────┬─┬──────────────┬─┬──────┤
│ Call │  Contact  │◀│   Messages   │▶│Device│  ← 60vh
│Panel │  Panel    │ │   Panel      │ │Panel │
├──────┴───────────┴─┴──────────────┴─┴──────┤
│                   Log Panel                 │  ← 30vh
└─────────────────────────────────────────────┘
```

- Collapsible contact panel (left toggle `◀`)
- Collapsible device panel (right toggle `▶`)
- Call panel muncul/hilang berdasarkan ada/tidaknya call aktif
- Semua reactive via GetX `Obx()`

---

#### [NEW] [app_bar_widget.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/home/widgets/app_bar_widget.dart)

- Logo image kiri
- Kanan: server status (hijau/merah dot), device count badge, settings button, clock
- Settings button → buka `SettingsView` dialog

#### [NEW] [clock_widget.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/home/widgets/clock_widget.dart)

Port dari [Clock.jsx](file:///Users/user/Projects/ip-call-app/src/Clock.jsx) — Indonesian date/time:
- Hari: Senin, Selasa, ...
- Bulan: Januari, Februari, ...
- Format: "Jumat, 13 Juni 2026" + "11:37"

#### [NEW] [call_panel_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/call/call_panel_view.dart)

Port dari [Telpon.jsx](file:///Users/user/Projects/ip-call-app/src/Telpon.jsx) — 3 states:
1. **Ringing** — animasi, nama, stopwatch, tombol jawab (incoming), kosong (outgoing)
2. **On Session** — animasi, nama, stopwatch, tombol hangup (setelah 5 detik)
3. **Queue** — list antrian call ke-2, 3, dst

#### [NEW] [message_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/message/message_view.dart)

Port dari [Message.jsx](file:///Users/user/Projects/ip-call-app/src/Message.jsx) — Color-coded pulsing cards:

| Code | Color | Label |
|---|---|---|
| `e` | Merah | DARURAT |
| `i` | Hijau | INFUS |
| `b` | Biru | CODE BLUE |
| `0` | Abu | PANGGILAN TIDAK TERJAWAB |
| `a` | Oranye | PANGGILAN PERAWAT |
| `w`/`q` | Kuning | TELEPON |

Per card: label + username + stopwatch + delete button (X) + call button (untuk `q`)

#### [NEW] [contact_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/contact/contact_view.dart)

Port dari [Kontak.jsx](file:///Users/user/Projects/ip-call-app/src/Kontak.jsx) — Tab bar: **Kontak** / **Riwayat Telepon**

#### [NEW] [contact_list_widget.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/contact/widgets/contact_list_widget.dart)

Port dari [KontakList.jsx](file:///Users/user/Projects/ip-call-app/src/KontakList.jsx):
- Search input
- Expandable per-room groups
- Per bed: username, call button (hanya jika active), off indicator jika tidak active

#### [NEW] [history_list_widget.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/contact/widgets/history_list_widget.dart)

Port dari `ListLogTelepon` di [Kontak.jsx](file:///Users/user/Projects/ip-call-app/src/Kontak.jsx) line 123-250:
- Date picker
- List history: icon (↙ hijau = masuk, ↙ merah = tidak terjawab, ↗ hijau = keluar) + username + duration + timestamp
- Call button per item

#### [NEW] [device_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/device/device_view.dart)

Port dari [Devices.jsx](file:///Users/user/Projects/ip-call-app/src/Devices.jsx) render():
- Header "Daftar Perangkat"
- Expandable per-room: room name + status dot (red/green/blue pulse) + on/off count
- Per device: username + on/off icon + message color indicator

#### [NEW] [log_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/log/log_view.dart)

Port dari [Log.jsx](file:///Users/user/Projects/ip-call-app/src/Log.jsx):
- Header "LOG" + date picker
- Table: Timestamp | Kategori (color dot + name) | Ruang (username) | Waktu (formatted duration)
- Scrollable

#### [NEW] [settings_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/settings/settings_view.dart)

**Fitur baru** — Dialog/page:

```
┌─────────────────────────────────┐
│           Settings              │
├─────────────────────────────────┤
│ Server Host: [_______________]  │
│                                 │
│ ── MQTT ──                      │
│ Port:        [1883___________]  │
│                                 │
│ ── Database ──                  │
│ Port:        [3306___________]  │
│ Username:    [_______________]  │
│ Password:    [_______________]  │
│ DB Name:     [ip-call________]  │
│                                 │
│ ── SIP ──                       │
│ Domain:      [_______________]  │
│ Port:        [5060___________]  │
│ Username:    [_______________]  │
│ Password:    [_______________]  │
│ WS URL:      [_______________]  │
│                                 │
│ ── Linux Only ──  (if Linux)    │
│ [WiFi Settings] [Volume Ctrl]   │
│                                 │
│   [Test Connection]   [Save]    │
└─────────────────────────────────┘
```

#### [NEW] [linux_wifi_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/platform/linux_wifi_view.dart)

- [Scan] button
- Table: SSID | Signal | Security | [Connect]
- Active connection indicator + [Disconnect]
- Password dialog saat connect

#### [NEW] [linux_volume_view.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/views/platform/linux_volume_view.dart)

- Master Volume: Slider (0-100%) + Mute toggle
- Capture Volume: Slider (0-100%) + Mute toggle
- [Refresh] button

---

### 5. Bindings & Routes

#### [NEW] [app_binding.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/bindings/app_binding.dart)

```dart
class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put(StorageService());
    Get.put(DatabaseService());
    Get.put(MqttService());
    Get.put(SipService());
    Get.put(AudioService());
    
    // Controllers
    Get.put(HomeController());
    Get.put(CallController());
    Get.put(MessageController());
    Get.put(DeviceController());
    Get.put(ContactController());
    Get.put(LogController());
    Get.put(SettingsController());
    
    // Linux only
    if (Platform.isLinux) {
      Get.put(LinuxWifiService());
      Get.put(LinuxVolumeService());
      Get.put(LinuxWifiController());
      Get.put(LinuxVolumeController());
    }
  }
}
```

#### [NEW] [app_pages.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/routes/app_pages.dart) & [app_routes.dart](file:///Users/user/Projects/ip_call_desktop/lib/app/routes/app_routes.dart)

Routes:
- `/` → HomeView
- `/settings` → SettingsView

#### [MODIFY] [main.dart](file:///Users/user/Projects/ip_call_desktop/lib/main.dart)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  
  runApp(GetMaterialApp(
    initialRoute: '/',
    getPages: AppPages.pages,
    initialBinding: AppBinding(),
    title: 'Nurse Call',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(...),
  ));
}
```

Jika `serverHost` kosong → HomeView otomatis buka SettingsView.

---

### 6. Assets

#### [NEW] `assets/sounds/`
Copy dari [src/sounds/](file:///Users/user/Projects/ip-call-app/src/sounds):
- `ringing.ogg`, `rejected.mp3`, `opening.mp3`

#### [NEW] `assets/speaks/`
Copy dari [src/speaks/](file:///Users/user/Projects/ip-call-app/src/speaks):
- satu.ogg – sembilan.ogg, sepuluh.ogg, sebelas.ogg, belas.ogg, puluh.ogg
- darurat.ogg, infus.ogg, blue.ogg, telepon.ogg, tidak_terjawab.ogg, perawat.ogg
- A.mp3 – L.mp3

#### [NEW] `assets/icons/`
Copy dari [src/icons/](file:///Users/user/Projects/ip-call-app/src/icons):
- `bg-20.png`, `logo_web_2.png`, `on.svg`, `off.svg`

#### Dynamic sounds (dari DB `mastersound`)
- Saat init, query `mastersound` table
- Download file dari `http://{serverHost}/ip-call/{source}` → simpan di `path_provider.getApplicationSupportDirectory()/sounds/`
- Contoh: `mastersound.name = "Ruang"`, `source = "static/ruang.mp3"` → download → cache lokal

---

### 7. MQTT Logic Mapping

Sama persis dengan project lama, **tanpa perubahan logika**:

```
┌─────────────────────┬─────────────────────────────────────────────┐
│ MQTT Topic          │ Handler (sama dengan App.jsx)                │
├─────────────────────┼─────────────────────────────────────────────┤
│ toilet/{id}         │ e → addMessage, c/x → deleteMessage(darurat)│
│ bed/{id}            │ e → check mode(DB): 2→msg(b), else→msg(e)  │
│                     │ c/x → check mode(DB): 2→del(blue), else→del│
│ infus/{id}          │ i → addMessage, c/x → deleteMessage(infus) │
│ blue/{id}           │ b → addMessage, c/x → deleteMessage(blue)  │
│ assist/{id}         │ a → addMessage, c/x → deleteMessage(assist)│
│ call/{id}           │ 1 → check mode(DB), create incoming call   │
│                     │ c/x → deleteMessage(call)                  │
│ tidakterjawab/{id}  │ x → deleteMessage("")                      │
│ room/{id}           │ e → addMessage, c → deleteMessage(darurat) │
│ internal            │ → serverState=true, reset 10s timeout      │
│ aktif               │ → set device active, start timeout         │
│ panggil             │ 1 → onSession=true, clear timeouts [TETAP] │
│ dotmatrix           │ ← publish only (dari speak system)         │
└─────────────────────┴─────────────────────────────────────────────┘
```

> [!NOTE]
> Satu-satunya perubahan: `panggil` topic untuk **inisiasi** call sekarang via SIP UA, tapi **mendengarkan** response `panggil` = `1` tetap via MQTT.

---

### 8. SIP Call Flow

```
┌────────────────────────────────────────────────────────┐
│           Call Flow: SIP + MQTT Combined               │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Outgoing Call:                                        │
│  1. sipService.makeCall(number)       ← SIP UA        │
│  2. mqtt.publish("call/{id}", "a")    ← MQTT          │
│  3. Wait: MQTT "panggil" = "1"        ← device jawab  │
│       OR: sipService.onCallAccepted   ← SIP event     │
│  4. Set onSession = true                               │
│                                                        │
│  Incoming Call (dari device MQTT):                     │
│  1. MQTT "call/{id}" = "1" received                    │
│  2. Show ringing UI                                    │
│  3. User klik Answer:                                  │
│     a. sipService.makeCall(phone)     ← SIP UA        │
│     b. mqtt.publish("call/{id}", "a") ← MQTT          │
│  4. Wait answer via SIP/MQTT                           │
│                                                        │
│  Hang Up:                                              │
│  1. sipService.hangUp()               ← SIP UA        │
│  2. mqtt.publish("call/{id}", "h")    ← MQTT          │
│  3. mqtt.publish("stop/{id}", ...)    ← MQTT          │
│  4. DB: INSERT INTO history           ← MySQL         │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Verification Plan

### Build Check

```bash
flutter analyze
flutter build macos    # dev machine
flutter build linux    # di mesin Linux
flutter build windows  # di mesin Windows
```

### Manual Verification

1. **Settings & Connection**:
   - Buka app → auto redirect ke Settings (karena host kosong)
   - Isi semua config → Test Connection → Save
   - MQTT connected ✓, DB connected ✓, SIP registered ✓

2. **MQTT Messages**:
   - Publish test messages via MQTT Explorer
   - Verifikasi setiap tipe (darurat, infus, blue, assist, call, toilet, room)
   - Cek add/delete message behavior match persis

3. **SIP Call**:
   - Outgoing call → ringing → answer → hangup
   - Incoming call via device → ringing → answer → session → hangup
   - Timeout tidak terjawab
   - SIP error timeout 15s

4. **Audio/Speak**:
   - Speak sequence: kategori + room/bed name + number
   - Dynamic sounds loaded dari DB
   - Ringing/rejected sounds

5. **Database**:
   - Contact list loaded ✓
   - Device list loaded ✓
   - History by date ✓
   - Log by date ✓
   - Create history & log entries ✓

6. **Linux** (di mesin Linux):
   - WiFi scan, connect, disconnect
   - Volume slider Master/Capture
