# Implementation Plan — Fix IP Call Desktop Bugs

This implementation plan addresses the bugs and issues reported in [report.md](file:///media/psf/External-Projects/ip_call_desktop/report.md) for the Nurse Call Desktop application, ensuring it runs reliably for 24/7 operation.

## User Review Required

> [!IMPORTANT]
> The database connection helper changes introduce a connection mutex to prevent concurrent `connect()` calls that leak MySQL connections.
> We will also separate the state saving of `calls` and `messages` into two different storage keys (`app_state_calls` and `app_state_messages`) to prevent cross-controller race conditions when writing to storage.

## Proposed Changes

### Database Service

#### [MODIFY] [database_service.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/database_service.dart)
- **C-03**: Wrap connection logic in a helper `_doConnect` and use `_connectFuture` as a proper mutex to prevent concurrent connection attempts.
- **C-07**: Add an `_isPingRunning` flag to `_startPingTimer` to prevent concurrent database queries when connection health check is slow.
- **L-07**: Wrap connection check in `testConnection()` with `try-finally` to ensure the temporary connection is closed even on connection timeout.

---

### MQTT Service

#### [MODIFY] [mqtt_service.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/mqtt_service.dart)
- **C-01**: Maintain a single `_updatesSubscription` stream subscription. Cancel the old subscription before creating a new one on reconnect, and cancel it on disconnect to prevent progressive memory leaks.
- **C-05**: Iterate over a copy of `_messageHandlers` (using `List.from(_messageHandlers)`) to prevent `ConcurrentModificationError` if handlers modify the list.

---

### SIP Service

#### [MODIFY] [sip_service.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/sip_service.dart)
- **H-11**: Implement auto-reconnect inside `transportStateChanged()` when the WebSocket transport disconnects.
- **C-04**: Ensure registration cleanly disposes the old helper and its listeners. Added safety logic to clean up callbacks when resetting.

---

### Audio Service

#### [MODIFY] [audio_service.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/audio_service.dart)
- **H-03**: Add an `_isSpeaking` guard in `speak()` to prevent overlapping audio playback when triggered concurrently.
- **H-10**: Re-create `AudioPlayer` instances if play fails (e.g., due to GStreamer crash).
- **L-05**: Static final compiled `RegExp` instance for character checking to avoid recreating it on every call.

---

### Call Controller

#### [MODIFY] [call_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/call_controller.dart)
- **C-04**: Expose a public `bindSipCallbacks()` method to easily re-bind SIP callbacks to the controller when SIP is re-registered.
- **C-08 & C-09**: Add a `_timing_out` flag to calls when they are timing out to prevent double-processing. Make `_handleSingleCallTimeout` async/await and update index search safely. Use GetX `ever` worker on `calls` to automatically manage the `callSeconds` timer.
- **H-01**: Ensure `isAnswering` is reset to `false` in `hangUp()` and inside a try-catch fallback.
- **H-04**: Save and restore `calls` state using a dedicated key `app_state_calls` in `StorageService`.

---

### Message Controller

#### [MODIFY] [message_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/message_controller.dart)
- **C-02**: Re-create/update the `_speakInterval` timer on message addition/deletion, resetting `_indexInterval` and Counter to 0. Build a clean `_doSpeak` helper method.
- **H-04**: Save and restore `messages` state using a dedicated key `app_state_messages` in `StorageService`.
- **H-06**: Retrieve `toiletPriority` from `HomeController` instead of executing a database query for every incoming message.
- **M-01**: Use exact prefix matching (e.g., `startsWith('bed/')`) instead of broad `contains()` checks to process MQTT topics safely.
- **M-10**: Parse device IDs by splitting topics on `/` and taking the last segment instead of hardcoded `substring(length - 6)`.

---

### Home Controller

#### [MODIFY] [home_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/home_controller.dart)
- **H-09**: Initialize each service in its own try-catch block inside `_initServices()` so failure of one service doesn't block the startup initialization of others.
- **C-04 & M-12**: In `refreshAllConnections()`, re-bind SIP callbacks and trigger data reloading on `DeviceController` and `ContactController`.

---

### Settings Controller

#### [MODIFY] [settings_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/settings_controller.dart)
- **C-10**: Add a `clearAllMessages()` wrapper to `MessageController` to cleanly cancel the speak timer and clear state. Call this in `resetData()`.
- **C-04 & M-12**: In `save()`, re-bind SIP callbacks and trigger data reloading on `DeviceController` and `ContactController`.

---

### Device & Contact Controllers

#### [MODIFY] [device_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/device_controller.dart)
- **H-02**: Remove the device timer entry from `_deviceTimers` Map when the timer triggers.
- **H-05**: Safe cast list data to `List<Map<String, dynamic>>` using `.cast<Map<String, dynamic>>()`.
- **M-07**: Add an `_isSubscribing` guard to `_subscribeAll()` to prevent race conditions and duplicate subscriptions. Expose `loadDevices()` publicly.

#### [MODIFY] [contact_controller.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/controllers/contact_controller.dart)
- **H-02**: Remove the device timer entry from `_deviceTimers` Map when the timer triggers.
- **H-05**: Safe cast list data to `List<Map<String, dynamic>>` using `.cast<Map<String, dynamic>>()`.
- **M-12**: Expose `loadContacts()` publicly.

---

### Storage Service

#### [MODIFY] [storage_service.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/services/storage_service.dart)
- **H-04**: Add `appStateCalls` and `appStateMessages` properties to separate persisted state keys.

---

### Views

#### [MODIFY] [message_view.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/message/message_view.dart)
- **C-06**: Recalculate stopwatch times from scratch to avoid accumulating deleted messages, and only invoke `setState()` if active durations changed.

#### [MODIFY] [log_view.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/log/log_view.dart)
- **H-08**: Replace `SingleChildScrollView` + `Column` with a virtualized `ListView.builder` to support rendering thousands of logs without UI degradation.

#### [MODIFY] [home_view.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/home/home_view.dart)
- **H-07**: Check `Get.isDialogOpen` before launching the `SettingsView` dialog to prevent stacking multiple configuration dialogs.

#### [MODIFY] [settings_view.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/settings/settings_view.dart)
- **M-11**: Remove the redundant outer `GetBuilder<HomeController>` wrapper and use `Obx` directly.

#### [MODIFY] [call_panel_view.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/call/call_panel_view.dart)
- **M-08**: Use the direct index parameter from `itemBuilder` instead of calling `.indexOf()` on mutated copy maps to find stopwatch seconds.

#### [MODIFY] [linux_wifi_view.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/platform/linux_wifi_view.dart)
- **M-05**: Implement a dedicated `StatefulWidget` for the connection sub-dialog to guarantee the `TextEditingController` is disposed cleanly.

#### [MODIFY] [admin_webview_dialog.dart](file:///media/psf/External-Projects/ip_call_desktop/lib/app/views/home/widgets/admin_webview_dialog.dart)
- **M-03**: Load `about:blank` in `dispose()` to release native webview resources cleanly.
- **M-04**: Add a 15-second timeout to the `http.get` call.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure code is clean and type-safe.
- Run `flutter build linux` or `flutter run` if local emulator/compilation is available, or manually verify compilation correctness.

### Manual Verification
- Verify the home page configuration dialog does not stack.
- Check that resetting data cancels the audio announcer.
- Confirm connection updates and saving configuration reload device lists successfully.
