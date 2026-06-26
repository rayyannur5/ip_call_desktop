import 'package:get/get.dart';
import 'package:sip_ua/sip_ua.dart';
import 'storage_service.dart';

class SipService extends GetxService implements SipUaHelperListener {
  SIPUAHelper? _helper;
  Call? _activeCall;
  final isRegistered = false.obs;
  final callState = CallStateEnum.NONE.obs;

  /// Callbacks
  void Function()? onCallAccepted;
  void Function()? onCallEnded;
  void Function(Call call)? onIncomingCall;

  Future<void> register() async {
    final storage = Get.find<StorageService>();
    if (storage.sipDomain.isEmpty || storage.sipUsername.isEmpty) return;

    _helper = SIPUAHelper();
    _helper!.addSipUaHelperListener(this);

    final settings = UaSettings();
    settings.webSocketUrl = storage.sipWsUrl.isNotEmpty
        ? storage.sipWsUrl
        : 'ws://${storage.sipDomain}:${storage.sipPort}/ws';
    settings.uri = 'sip:${storage.sipUsername}@${storage.sipDomain}';
    settings.authorizationUser = storage.sipUsername;
    settings.password = storage.sipPassword;
    settings.displayName = storage.sipUsername;
    settings.userAgent = 'NurseCall Flutter Desktop';
    settings.transportType = TransportType.WS;
    settings.webSocketSettings.allowBadCertificate = true;

    try {
      _helper!.start(settings);
    } catch (e) {
      print('SIP Register Error: $e');
    }
  }

  Future<void> makeCall(String number) async {
    if (_helper == null) return;
    final storage = Get.find<StorageService>();
    final target = 'sip:$number@${storage.sipDomain}';
    try {
      await _helper!.call(target, voiceOnly: true);
    } catch (e) {
      print('SIP Make Call Error: $e');
    }
  }

  void answerCall() {
    if (_activeCall != null) {
      _activeCall!.answer(_helper!.buildCallOptions(true));
    }
  }

  void hangUp() {
    if (_activeCall != null) {
      _activeCall!.hangup();
      _activeCall = null;
    }
  }

  void unregister() {
    try {
      _helper?.stop();
      _helper?.removeSipUaHelperListener(this);
    } catch (_) {}
    _helper = null;
    isRegistered.value = false;
  }

  // --- SipUaHelperListener implementation ---

  @override
  void registrationStateChanged(RegistrationState state) {
    isRegistered.value = state.state == RegistrationStateEnum.REGISTERED;
    print('SIP Registration: ${state.state}');
  }

  @override
  void callStateChanged(Call call, CallState state) {
    _activeCall = call;
    callState.value = state.state;
    print('SIP Call State: ${state.state}');

    switch (state.state) {
      case CallStateEnum.CONFIRMED:
        onCallAccepted?.call();
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _activeCall = null;
        onCallEnded?.call();
        break;
      case CallStateEnum.CALL_INITIATION:
        if (call.direction == Direction.incoming) {
          onIncomingCall?.call(call);
        }
        break;
      default:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    print('SIP Transport: ${state.state}');
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // Not used in this app
  }

  @override
  void onNewNotify(Notify ntf) {
    // Not used in this app
  }

  @override
  void onNewReinvite(ReInvite event) {
    // Not used in this app
  }

  @override
  void onClose() {
    unregister();
    super.onClose();
  }
}
