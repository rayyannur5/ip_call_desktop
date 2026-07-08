import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart' as pkg_logger;
// sip_ua doesn't re-export its Log class from the package barrel file, but
// its loggingLevel setter is the only supported way to quiet its stdout spam.
// ignore: implementation_imports
import 'package:sip_ua/src/logger.dart' as sip_ua_logger;
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/services/app_logger.dart';

import 'package:window_manager/window_manager.dart';

const _tag = 'Main';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await logger.init();
    // sip_ua defaults to printing every SIP protocol frame straight to
    // stdout — drown that out, we only care about its warnings/errors.
    sip_ua_logger.Log.loggingLevel = pkg_logger.Level.warning;
    await windowManager.ensureInitialized();
    await windowManager.setFullScreen(true);

    // Filter out the annoying FlutterWebRTC PlatformException on event channel cancellation
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final exceptionStr = details.exception.toString();
      if (exceptionStr.contains('peerConnectionEvent') &&
          exceptionStr.contains('No active stream to cancel')) {
        logger.d(_tag, 'Suppressed WebRTC event channel cancel error.');
        return;
      }
      logger.e(_tag, 'Uncaught Flutter framework error', details.exception, details.stack);
      originalOnError?.call(details);
    };

    await GetStorage.init();

    final box = GetStorage();
    final isDark = box.read('is_dark_mode') ?? false;
    final themeColorVal = box.read('theme_color_value') ?? 0xFF2563EB;
    final themeColor = Color(themeColorVal);

    runApp(
      GetMaterialApp(
        title: 'Nurse Call',
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.home,
        getPages: AppPages.pages,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: themeColor,
            brightness: isDark ? Brightness.dark : Brightness.light,
            surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
        ),
      ),
    );
  }, (error, stack) {
    // Gracefully catch and log all asynchronous network socket errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Broken pipe') ||
        error.toString().contains('gst-resource-error-quark')) {
      logger.w(_tag, 'Caught asynchronous system/network error', error, stack);
    } else {
      logger.e(_tag, 'Uncaught zone error', error, stack);
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
        ),
      );
    }
  });
}
