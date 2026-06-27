import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';

import 'package:window_manager/window_manager.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.setFullScreen(true);

    // Filter out the annoying FlutterWebRTC PlatformException on event channel cancellation
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final exceptionStr = details.exception.toString();
      if (exceptionStr.contains('peerConnectionEvent') &&
          exceptionStr.contains('No active stream to cancel')) {
        debugPrint('Suppressed WebRTC event channel cancel error.');
        return;
      }
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
      debugPrint('Caught asynchronous system/network error: $error');
    } else {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
        ),
      );
    }
  });
}
