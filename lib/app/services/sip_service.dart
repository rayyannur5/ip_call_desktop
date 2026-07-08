import 'package:get/get.dart';
import 'package:sip_ua/sip_ua.dart';
import 'app_logger.dart';
import 'storage_service.dart';

const _tag = 'SipService';

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

    if (_helper != null) {
      unregister();
    }

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
    } catch (e, st) {
      logger.e(_tag, 'Register error', e, st);
    }
  }

  Future<void> makeCall(String number) async {
    if (_helper == null) return;
    final storage = Get.find<StorageService>();
    final target = 'sip:$number@${storage.sipDomain}';
    try {
      await _helper!.call(target, voiceOnly: true);
    } catch (e, st) {
      logger.e(_tag, 'Make call error', e, st);
    }
  }

  void answerCall() {
    if (_activeCall != null) {
      _activeCall!.answer(_helper!.buildCallOptions(true));
    }
  }

  void hangUp() {
    if (_activeCall != null) {
      try {
        _activeCall!.hangup();
      } catch (e, st) {
        logger.e(_tag, 'Hangup error', e, st);
      }
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
    logger.i(_tag, 'Registration state: ${state.state}');
  }

  @override
  void callStateChanged(Call call, CallState state) {
    _activeCall = call;
    callState.value = state.state;
    logger.i(_tag, 'Call state: ${state.state}');

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
    logger.i(_tag, 'Transport state: ${state.state}');
    if (state.state == TransportStateEnum.DISCONNECTED) {
      Future.delayed(const Duration(seconds: 5), () {
        if (_helper != null && !isRegistered.value) {
          register();
        }
      });
    }
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
