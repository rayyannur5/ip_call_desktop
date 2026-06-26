import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await GetStorage.init();

    runApp(
      GetMaterialApp(
        title: 'Nurse Call',
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.home,
        getPages: AppPages.pages,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3B82F6),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF3F4F6),
          fontFamily: 'Roboto',
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
