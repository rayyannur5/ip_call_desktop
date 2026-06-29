# 🔍 Bug Report — IP Call Desktop (Nurse Call)
## Audit Menyeluruh untuk Aplikasi 24/7

> Aplikasi ini didesain untuk berjalan terus-menerus tanpa restart. Semua bug diurutkan berdasarkan tingkat keparahan. Audit dilakukan oleh 3 reviewer secara paralel (Services, Controllers, Views) dan dikompilasi menjadi satu laporan terpadu.

---

## Ringkasan Temuan

| Severity | Jumlah | Dampak pada 24/7 |
|----------|--------|-------------------|
| 🔴 CRITICAL | 10 | Akan menyebabkan crash, resource habis, atau fitur mati dalam hitungan jam/hari |
| 🟠 HIGH | 12 | Akan menyebabkan degradasi performa secara bertahap |
| 🟡 MEDIUM | 12 | Berpotensi menyebabkan perilaku tidak terduga |
| 🔵 LOW | 8 | Masalah kecil, best practice |

---

## 🔴 CRITICAL — Harus Diperbaiki Sebelum Deploy 24/7

---

### C-01: MQTT Stream Subscription Leak (Memory Leak Progresif)
**File**: [mqtt_service.dart:59](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/mqtt_service.dart#L59)
**Kategori**: Memory Leak

> [!CAUTION]
> Setiap kali `connect()` dipanggil (reconnect, refresh, settings save), subscription stream baru dibuat TANPA membatalkan subscription lama.

```dart
// Line 59 — subscription baru ditambah setiap reconnect
_client!.updates?.listen(_onMessage, onError: (e) {
  print('MQTT Updates stream error: $e');
});
```

**Masalah**: `StreamSubscription` yang dikembalikan oleh `.listen()` tidak pernah disimpan dan di-cancel. Setiap reconnect menambah listener baru → setiap message diproses N kali setelah N reconnect.

**Dampak 24/7**: Setelah berhari-hari, memory membengkak dan setiap MQTT message diproses berkali-kali.

**Fix**:
```dart
StreamSubscription? _updatesSubscription;

Future<void> connect() async {
  // ...
  if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
    isConnected.value = true;
    _updatesSubscription?.cancel();  // cancel yang lama
    _updatesSubscription = _client!.updates?.listen(_onMessage, onError: (e) {
      print('MQTT Updates stream error: $e');
    });
  }
}

Future<void> disconnect() async {
  _updatesSubscription?.cancel();
  _updatesSubscription = null;
  _processingTopics.clear();
  _client?.disconnect();
  _client = null;
  isConnected.value = false;
}
```

---

### C-02: `_speakInterval` Timer Leak + IndexError (Message Announcement Rusak)
**File**: [message_controller.dart:258-318](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/message_controller.dart#L258-L318)
**Kategori**: Memory Leak / Crash

> [!CAUTION]
> Ini adalah bug paling berbahaya — bisa menyebabkan announcement berhenti total atau crash loop.

**Masalah Ganda**:

1. **Timer TIDAK di-recreate ketika messages berubah**: Jika `_speakInterval` sudah aktif saat message baru masuk, timer TIDAK di-restart. Akibatnya:
   - `_indexInterval` tidak di-reset saat message ditambah/dihapus
   - Insert di index 0 (toilet priority) menggeser semua message tapi `_indexInterval` tetap
   - Jika `intervalSpeaks` berubah via refresh, timer tetap jalan dengan interval lama

2. **`_indexInterval` Out-of-Bounds**: Bisa menyebabkan `RangeError` saat mengakses `messages[_indexInterval]`. Meskipun ada try-catch, ini menyebabkan speak terhenti.

3. **Speak awal menggunakan index yang salah** (line 268-272): Category dari index 0 tapi audio dari `_indexInterval`. Kalau `_indexInterval != 0`, yang diucapkan berbeda dari yang seharusnya.

**Fix**:
```dart
void _newMessage() {
  // Always reset index if out of bounds
  if (_indexInterval >= messages.length) {
    _indexInterval = 0;
    _counterIndexInterval = 0;
  }

  if (messages.isNotEmpty) {
    if (_speakInterval == null) {
      _doSpeak();  // Initial speak
      final home = Get.find<HomeController>();
      _speakInterval = Timer.periodic(
        Duration(milliseconds: home.intervalSpeaks),
        (_) => _doSpeak(),
      );
    }
  } else {
    _speakInterval?.cancel();
    _speakInterval = null;
    _indexInterval = 0;
    _counterIndexInterval = 0;
  }
}

void _doSpeak() {
  if (messages.isEmpty) return;
  if (_indexInterval >= messages.length) {
    _indexInterval = 0;
    _counterIndexInterval = 0;
  }
  // ...speak logic
}
```

---

### C-03: Database Race Condition — Concurrent `connect()` Calls
**File**: [database_service.dart:12-45](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/database_service.dart#L12-L45)
**Kategori**: Race Condition / Resource Leak

> [!CAUTION]
> Multiple concurrent queries bisa menyebabkan simultaneous reconnect, leaking MySQL connections hingga `max_connections` habis.

**Masalah**: `_connectFuture` di-null-kan di blok `finally` segera setelah connect selesai. Ini membuka window untuk:
1. Caller A connect selesai → `_connectFuture = null`  
2. Query A gagal → `_executeSafe` retry → `connect()` lagi
3. Ping timer juga detect disconnect → `connect()` lagi
4. = 2 koneksi dibuat bersamaan, 1 leaked

**Fix**: Proper mutex:
```dart
Future<void> connect() async {
  if (_connectFuture != null) {
    return _connectFuture!;
  }
  _connectFuture = _doConnect();
  try {
    await _connectFuture!;
  } finally {
    _connectFuture = null;
  }
}
```

---

### C-04: SIP Callbacks Hilang Setelah Reconnect — Panggilan Tidak Akan Dijawab
**File**: [sip_service.dart:12-14](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/sip_service.dart#L12-L14) + [call_controller.dart:36-37](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L36-L37)
**Kategori**: Logic Bug — Fitur Mati

> [!CAUTION]
> Setelah `refreshAllConnections()` atau `SettingsController.save()`, semua incoming call tidak bisa dijawab lagi!

```dart
// SipService — simple function pointer callbacks
void Function()? onCallAccepted;
void Function()? onCallEnded;

// CallController.onInit() — hanya set SEKALI
sip.onCallAccepted = _onSipCallAccepted;
sip.onCallEnded = _onSipCallEnded;
```

**Masalah**: `CallController.onInit()` hanya jalan sekali. Ketika SIP di-unregister dan re-register (via refresh/save):
1. `sip.unregister()` → `_helper = null` (callbacks masih di-set di instance lama)
2. `sip.register()` → `_helper = SIPUAHelper()` baru, tapi **callbacks tidak di-set ulang**
3. SIP call masuk → `onCallAccepted` adalah null → call tidak pernah "accepted"

**Fix**: Set ulang callbacks di `register()` atau simpan callbacks dan apply ke helper baru.

---

### C-05: Concurrent Modification pada `_messageHandlers` List
**File**: [mqtt_service.dart:98-100](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/mqtt_service.dart#L98-L100)
**Kategori**: Crash

```dart
for (final handler in _messageHandlers) {
  handler(topic, message);
}
```

**Masalah**: Handler bisa memanggil code yang secara sinkron memodifikasi `_messageHandlers` (misalnya: handler trigger pembuatan controller baru yang `addMessageHandler`, atau handler memicu `removeMessageHandler`). Ini akan throw `ConcurrentModificationError`.

**Fix**: Iterate over copy:
```dart
for (final handler in List.from(_messageHandlers)) {
  handler(topic, message);
}
```

---

### C-06: `MessageView` — `_seconds` Map Unbounded Growth (Memory Leak)
**File**: `message_view.dart` (Views)
**Kategori**: Memory Leak

**Masalah**: Map `_seconds` di `MessageView` (StatefulWidget) mengakumulasi entry untuk setiap topic message yang pernah dilihat. Entry **tidak pernah dihapus** ketika message di-delete. Ditambah, `Timer.periodic` memanggil `setState()` SETIAP DETIK tanpa kondisi, memaksa full widget rebuild terus-menerus.

**Fix**: Rebuild `_seconds` dari scratch setiap tick (bukan akumulasi), dan hanya `setState` jika ada perubahan.

---

### C-07: Ping Timer Overlap — Concurrent DB Queries
**File**: [database_service.dart:81-86](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/database_service.dart#L81-L86)
**Kategori**: Race Condition

```dart
_pingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
  await checkConnectionHealth();
});
```

**Masalah**: Jika `checkConnectionHealth()` memakan waktu > 10 detik (network timeout), tick berikutnya fire sementara yang sebelumnya masih berjalan → concurrent DB queries.

**Fix**:
```dart
bool _isPingRunning = false;
_pingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
  if (_isPingRunning) return;
  _isPingRunning = true;
  try { await checkConnectionHealth(); }
  finally { _isPingRunning = false; }
});
```

---

### C-08: `calls` List Race Condition — Modifikasi dari Banyak Sumber
**File**: [call_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart)
**Kategori**: Race Condition

**Masalah**: RxList `calls` dimutasi dari 5+ sumber berbeda:
1. `_updateCallSeconds()` via timer setiap detik → `_handleSingleCallTimeout` → `calls.removeAt()` dalam `.then()` async
2. `_handleMqttMessage()` dari MQTT synchronous
3. `hangUp()` → `calls.removeAt(0)`
4. `handlerAnswer()` → SIP error timer modifikasi calls
5. `_onSipCallEnded()` → panggil `hangUp()`

**Contoh race**: `_updateCallSeconds()` iterasi `calls` dalam for-loop (line 84), sementara `_handleMqttMessage` secara sinkron trigger modifikasi list. `.then()` callback di `_handleSingleCallTimeout` (line 152) bisa jalan setelah list sudah berubah total.

**Fix**: Gunakan flag/guard dan hindari async `.then()` yang modifikasi shared state. Gunakan `await` instead:
```dart
// Instead of:
db.createHistory(id, 2).then((_) { calls.removeAt(index); });
// Use:
await db.createHistory(id, 2);
final index = calls.indexWhere((c) => c['topic'] == topic);
if (index != -1) calls.removeAt(index);
```

---

### C-09: `_handleSingleCallTimeout` Double Processing
**File**: [call_controller.dart:100-122](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L100-L122)
**Kategori**: Race Condition

**Masalah**: `_updateCallSeconds()` dipanggil setiap detik. Jika `_handleSingleCallTimeout` memanggil `db.createHistory().then(...)` yang async, call belum dihapus dari list saat tick berikutnya terjadi. Akibatnya, call yang SAMA bisa masuk `callsToTimeout` **dua kali**, menyebabkan:
- Double history entry di database
- Double MQTT publish
- Double notification "tidak terjawab"

**Fix**:
```dart
// Tandai call yang sedang di-timeout
if (call['type'] == 'incoming' && call['created_at'] == null 
    && call['_timing_out'] != true && second >= timeoutLimitSec) {
  call['_timing_out'] = true;
  callsToTimeout.add(call);
}
```

---

### C-10: `resetData()` Tidak Cancel `_speakInterval` Timer
**File**: [settings_controller.dart:199-204](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/settings_controller.dart#L199-L204)
**Kategori**: Crash Loop

```dart
final msgCtrl = Get.find<MessageController>();
msgCtrl.messages.clear();
// ❌ Tidak memanggil _newMessage() untuk cancel timer
```

**Masalah**: Setelah `messages.clear()`, timer `_speakInterval` tetap berjalan dan mengakses `messages[_indexInterval]` pada list kosong → `RangeError` setiap `intervalSpeaks` ms, terus-menerus sampai ada message baru.

**Fix**: Tambahkan cancel timer atau panggil internal method:
```dart
msgCtrl.messages.clear();
msgCtrl._speakInterval?.cancel();
msgCtrl._speakInterval = null;
```

---

## 🟠 HIGH — Perlu Diperbaiki Segera

---

### H-01: `isAnswering` Bisa Stuck `true` Selamanya
**File**: [call_controller.dart:406](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L406)

`isAnswering.value = true` hanya di-reset di `_onSipCallAccepted` atau SIP error timer (15s). Jika SIP library crash atau edge case dimana kedua callback tidak fire, `isAnswering` tetap `true` **selamanya** → semua future answer attempts diblokir.

**Fix**: Tambahkan reset di `hangUp()` dan timeout fallback.

---

### H-02: `_deviceTimers` Map Unbounded Growth
**File**: [device_controller.dart:15](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/device_controller.dart#L15), [contact_controller.dart:20](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/contact_controller.dart#L20)

Timer-timer disimpan di Map tetapi entry tidak pernah dihapus. Setiap device ID yang pernah kirim `aktif` message menambah entry. Meskipun timer di-cancel, Map entry tetap ada → memory grows indefinitely.

**Fix**: Hapus entry saat timeout fire:
```dart
_deviceTimers[item['id']] = Timer(
  Duration(milliseconds: _intervalUpdateStatus),
  () {
    item['active'] = false;
    _deviceTimers.remove(item['id']);  // Tambahkan ini
    devices.refresh();
  },
);
```

---

### H-03: Concurrent `speak()` Invocations — Audio Garbled
**File**: [audio_service.dart:173-232](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/audio_service.dart#L173-L232)

`speak()` dipanggil dari `_speakInterval` timer yang bisa overlap dengan speak yang sedang berjalan. Kedua invokasi compete untuk `_speakPlayer` → audio terpotong, subscription clash.

**Fix**:
```dart
bool _isSpeaking = false;
Future<void> speak(...) async {
  if (_isSpeaking) return;
  _isSpeaking = true;
  try { /* ... */ } finally { _isSpeaking = false; }
}
```

---

### H-04: `_saveState()` Cross-Controller Race
**File**: [call_controller.dart:61-70](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L61-L70), [message_controller.dart:45-54](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/message_controller.dart#L45-L54)

Keduanya write ke storage key `app_state` yang SAMA. Yang terakhir menang. Bisa menyebabkan data stale saat restore.

**Fix**: Centralize state saving di satu tempat atau gunakan key terpisah.

---

### H-05: Unsafe Cast `List<Map<String, dynamic>>` dari DB Data
**File**: [device_controller.dart:68](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/device_controller.dart#L68), [contact_controller.dart:74](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/contact_controller.dart#L74)

```dart
final deviceList = room['device'] as List<Map<String, dynamic>>;
```

Jika DB/JSON deserialization mengembalikan `List<dynamic>`, cast ini throw `TypeError` dan crash MQTT handler untuk SEMUA messages.

**Fix**: Gunakan safe cast: `(room['device'] as List).cast<Map<String, dynamic>>()`

---

### H-06: `addMessage()` Query DB untuk `toilet_priority` Setiap Pesan
**File**: [message_controller.dart:173-178](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/message_controller.dart#L173-L178)

Setiap incoming message trigger DB query ke utils table. Padahal `HomeController.toiletPriority` sudah memuat nilai ini.

**Fix**: `final tp = Get.find<HomeController>().toiletPriority.value;`

---

### H-07: Dialog Settings Bisa Stack Berkali-kali
**File**: [home_view.dart:22-24](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/home/home_view.dart#L22-L24)

Code ini di dalam `build()` yang di-wrap `Obx`. Setiap rebuild, jika `isConfigured` masih false, dialog baru ditambah di atas dialog lama.

**Fix**: Gunakan static flag.

---

### H-08: `LogView` Render Semua Log Tanpa Virtualization
**File**: Views — `log_view.dart`

Menggunakan `SingleChildScrollView` + `Column` dengan spread semua log entries. Tidak ada virtualization (`ListView.builder`). Setelah berhari-hari, log bisa ribuan entry → severe performance degradation.

**Fix**: Ganti dengan `ListView.builder`.

---

### H-09: `initCompleter` Tidak Di-reset Saat Refresh
**File**: [home_controller.dart:26](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/home_controller.dart#L26)

Setelah `_initServices()` selesai, completer sudah `completed` selamanya. Ketika `refreshAllConnections()` reload config, controllers yang sudah baca config lama tidak akan reload.

---

### H-10: AudioPlayer Tidak Recovery Setelah Error
**File**: [audio_service.dart:22-27](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/audio_service.dart#L22-L27)

Jika GStreamer (Linux audio backend) crash, `AudioPlayer` instance jadi permanently non-functional. Tidak ada recovery logic.

**Fix**: Recreate player jika play() gagal berulang.

---

### H-11: Tidak Ada SIP Auto-Reconnect
**File**: [sip_service.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/sip_service.dart)

Jika WebSocket transport putus, SIP registration hilang **permanen** sampai manual refresh. Untuk app 24/7, ini critical.

**Fix**: Tambahkan reconnect logic di `transportStateChanged`:
```dart
@override
void transportStateChanged(TransportState state) {
  if (state.state == TransportStateEnum.DISCONNECTED) {
    Future.delayed(Duration(seconds: 5), () => register());
  }
}
```

---

### H-12: `_timeout` Timer Dideklarasi tapi Tidak Pernah Di-start
**File**: [call_controller.dart:19](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L19)

`Timer? _timeout` dideklarasi, di-cancel di banyak tempat, tapi **tidak pernah di-assign value**. Logic timeout dari original App.jsx mungkin hilang saat porting.

---

## 🟡 MEDIUM — Perlu Diperhatikan

---

### M-01: Topic Matching Terlalu Lebar
**File**: [message_controller.dart:57-107](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/message_controller.dart#L57-L107)

`topic.contains('bed')` bisa match `"embedded"`, `topic.contains('blue')` bisa match `"bluetooth"`, dsb.

**Fix**: Gunakan `topic.startsWith('bed/')` atau regex.

---

### M-02: `hangUp()` Tidak Ada Re-entrancy Guard
**File**: [call_controller.dart:314-397](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L314)

Bisa dipanggil dari `_onSipCallEnded` dan `_updateCallSeconds` secara bersamaan → double remove dari list.

---

### M-03: `WebViewController` Tidak Di-dispose
**File**: [admin_webview_dialog.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/home/widgets/admin_webview_dialog.dart#L41-L44)

Native webview resources leaked setiap kali dialog dibuka/ditutup.

---

### M-04: HTTP Download Tanpa Timeout
**File**: [admin_webview_dialog.dart:144](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/home/widgets/admin_webview_dialog.dart#L144)

`http.get(uri)` tanpa timeout bisa hang selamanya.

---

### M-05: `TextEditingController` Leak di WiFi Dialog
**File**: Views — `linux_wifi_view.dart`

`TextEditingController` dibuat setiap kali dialog dibuka tapi tidak pernah di-dispose.

---

### M-06: `callSeconds` Timer Berjalan 24/7 Meski Tidak Ada Call
**File**: [call_controller.dart:40-42](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart#L40)

86.400 invokasi/hari tanpa perlu. CPU waste.

---

### M-07: `_subscribeAll()` Race Condition
**File**: [device_controller.dart:62-106](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/device_controller.dart#L62)

30s timer + `ever(mqtt.isConnected)` keduanya bisa trigger `_subscribeAll()` bersamaan → duplicate subscribe. Juga, dengan 100 device × 6 topic × 20ms delay = **12 detik** per siklus.

---

### M-08: `indexOf` pada Mutated Map di CallPanelView
**File**: [call_panel_view.dart:141](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/call/call_panel_view.dart#L141)

`controller.calls.indexOf(call)` — `call` bisa stale karena spread copy. Akan return -1, membuat `currentSeconds` selalu 0.

**Fix**: Gunakan `index` dari `itemBuilder` langsung.

---

### M-09: `_initServices` Partial Init Tanpa Retry
**File**: [home_controller.dart:52-88](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/home_controller.dart#L52)

Jika `mqtt.connect()` gagal, SIP dan Audio tidak pernah diinisialisasi. Completer tetap completed → downstream controllers proceed tanpa service.

---

### M-10: `substring()` Hardcoded Length
**File**: [message_controller.dart:227](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/message_controller.dart#L227)

`topic.substring(topic.length - 6)` mengasumsikan ID selalu 6 karakter. Jika tidak → wrong data atau `RangeError`.

---

### M-11: `GetBuilder` + `Obx` Redundant Wrapping di SettingsView
**File**: Views — `settings_view.dart`

Menggunakan `GetBuilder` (update-based) membungkus `Obx` (.obs-based). Redundant overhead.

---

### M-12: `service save()` / `refreshAllConnections()` Tidak Reload DeviceController/ContactController Data
**File**: [settings_controller.dart:137-163](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/settings_controller.dart#L137)

Setelah ganti server dan reconnect, device/contact data tetap dari server lama.

---

## 🔵 LOW — Minor Issues & Best Practice

---

### L-01: `print()` Seharusnya `debugPrint()` atau Logger
**File**: Hampir semua file (~50+ print statements)

Dalam 24/7, stdout buffer membengkak. Tidak ada level filtering atau timestamp.

---

### L-02: Debug `print` di `Obx` Rebuild (Setiap Detik)
**File**: [call_panel_view.dart:148](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/call/call_panel_view.dart#L148)

86.400 log lines/hari per active call. Bisa penuhkan disk/journal.

---

### L-03: Hardcoded Admin Password
**File**: [settings_controller.dart:172](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/settings_controller.dart#L172)

---

### L-04: WiFi Password Visible di Process Args
**File**: [linux_wifi_service.dart:46](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/platform/linux_wifi_service.dart#L46)

Password visible di `/proc/[pid]/cmdline` dan `ps aux`.

---

### L-05: `RegExp` Recreated Setiap Panggilan
**File**: [audio_service.dart:169](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/audio_service.dart#L169)

```dart
return RegExp(r'^[a-zA-Z]$').hasMatch(char);  // Buat RegExp baru setiap call
```

**Fix**: `static final _letterRegex = RegExp(r'^[a-zA-Z]$');`

---

### L-06: `Colors.black.withOpacity()` Deprecated
**File**: [home_view.dart:280](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/home/home_view.dart#L280) + multiple

Gunakan `withValues(alpha: ...)`.

---

### L-07: `testConnection()` Tidak Close Connection Saat Timeout
**File**: [database_service.dart:56-73](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/database_service.dart#L56-L73)

**Fix**: Gunakan try-finally untuk ensure `conn.close()`.

---

### L-08: GetX Version `get: ^5.0.0-release-candidate` (RC, Bukan Stable)
**File**: [pubspec.yaml](file:///media/psf/External-Projects/ip_call_desktop/pubspec.yaml)

Menggunakan release candidate untuk production 24/7 is risky.

---

## 📋 Prioritas Fix untuk 24/7 Deployment

### 🚨 HARUS Fix SEBELUM Deploy (Estimasi: ~3-4 jam)

| # | Bug ID | Issue | Est. |
|---|--------|-------|------|
| 1 | C-01 | MQTT Stream Leak | 10m |
| 2 | C-02 | Speak Timer Leak + IndexError | 30m |
| 3 | C-03 | DB Race Condition | 20m |
| 4 | C-04 | SIP Callbacks Lost After Reconnect | 15m |
| 5 | C-05 | Handler ConcurrentModification | 5m |
| 6 | C-06 | MessageView Memory Leak | 20m |
| 7 | C-07 | DB Ping Timer Overlap | 10m |
| 8 | C-08 | Calls List Race Condition | 30m |
| 9 | C-09 | Double Timeout Processing | 10m |
| 10 | C-10 | resetData Speak Timer Crash | 10m |

### ⚠️ Fix Dalam Minggu Pertama (Estimasi: ~2-3 jam)

| # | Bug ID | Issue | Est. |
|---|--------|-------|------|
| 1 | H-01 | isAnswering Permanently Stuck | 10m |
| 2 | H-02 | deviceTimers Unbounded Growth | 10m |
| 3 | H-03 | Concurrent speak() | 10m |
| 4 | H-04 | saveState Race | 20m |
| 5 | H-05 | Unsafe Cast | 10m |
| 6 | H-06 | DB Query per Message | 5m |
| 7 | H-07 | Dialog Stack | 10m |
| 8 | H-08 | LogView No Virtualization | 15m |
| 9 | H-09 | initCompleter Not Reset | 10m |
| 10 | H-10 | AudioPlayer No Recovery | 20m |
| 11 | H-11 | No SIP Auto-Reconnect | 20m |
| 12 | H-12 | _timeout Never Started | 15m |

---

## 🏗️ Rekomendasi Arsitektur untuk 24/7

> [!IMPORTANT]
> Selain memperbaiki bug di atas, pertimbangkan hal berikut:

### Essential untuk 24/7:
1. **Watchdog Timer**: Restart koneksi jika tidak ada heartbeat selama X menit
2. **Structured Logging**: Gunakan package `logger` dengan log rotation agar disk tidak penuh
3. **systemd Service**: Gunakan `Restart=always` sebagai safety net — jika app crash, otomatis restart
4. **Memory Monitoring**: Log memory usage periodik untuk deteksi leak dini

### Nice to Have:
5. **Connection Health Dashboard**: Tampilkan status DB/MQTT/SIP secara real-time di UI
6. **Graceful Degradation**: Jika DB mati, queue messages di local storage dan sync saat reconnect
7. **Telemetry**: Kirim health metrics ke server monitoring
8. **GetX Permanent Controllers**: Pastikan semua controller di-register dengan `permanent: true`
