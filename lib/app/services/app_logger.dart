import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Application-wide logger, built on top of `package:logger`.
///
/// - Console: pretty, colored, single-line — debug builds only.
/// - File: plain, single-line, written to `<app support dir>/logs/app.log` —
///   always on, at full debug verbosity, so field issues can be diagnosed
///   after the fact even in a release build. Size + count based rotation
///   (below) keeps this from growing unbounded.
///
/// File rotation is handled by `AdvancedFileOutput` (from `package:logger`):
/// once `app.log` passes [_maxFileSizeKB], it's renamed to a timestamped
/// backup and a fresh `app.log` is started. Only the [_maxBackupFiles] most
/// recent backups are kept; older ones are deleted automatically.
///
/// Usage:
/// ```dart
/// logger.i('SipService', 'Registered with SIP server');
/// logger.e('SipService', 'Register failed', error, stackTrace);
/// ```
class AppLogger {
  AppLogger._internal();

  static final AppLogger instance = AppLogger._internal();

  static const int _maxFileSizeKB = 50 * 1024; // 50 MB per file
  static const int _maxBackupFiles = 10;

  Logger? _console;
  Logger? _file;
  Future<void>? _initFuture;
  String? _logDirectoryPath;

  /// Directory holding `app.log` and its rotated backups (`null` until
  /// [init] has completed).
  String? get logDirectoryPath => _logDirectoryPath;

  /// Sets up console + file logging. Safe to call multiple times; the
  /// underlying work only runs once. Should be awaited once at app startup,
  /// before anything else logs.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (kDebugMode) {
      // Everything down to debug-level, straight to the console.
      _console = Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(printTime: true, colors: true),
        level: Level.debug,
      );
    }

    try {
      final supportDir = await getApplicationSupportDirectory();
      final logDir = Directory(p.join(supportDir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logDirectoryPath = logDir.path;

      final fileLogger = Logger(
        // Full debug verbosity, in every build — rotation already caps
        // total disk usage, so there's no need to also filter by level.
        filter: ProductionFilter(),
        printer: SimplePrinter(printTime: true, colors: false),
        level: Level.debug,
        output: AdvancedFileOutput(
          path: logDir.path,
          latestFileName: 'app.log',
          maxFileSizeKB: _maxFileSizeKB,
          maxRotatedFilesCount: _maxBackupFiles,
        ),
      );
      await fileLogger.init;
      _file = fileLogger;
      i('AppLogger', 'Logging initialized -> ${logDir.path}');
    } catch (error, stackTrace) {
      // File logging is a bonus, not a requirement — never let a logging
      // failure take the app down.
      debugPrint('AppLogger: failed to initialize file logging: $error\n$stackTrace');
    }
  }

  void d(String tag, String message) => _log(Level.debug, tag, message);

  void i(String tag, String message) => _log(Level.info, tag, message);

  void w(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _log(Level.warning, tag, message, error, stackTrace);

  void e(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _log(Level.error, tag, message, error, stackTrace);

  void _log(
    Level level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final line = '[$tag] $message';
    _console?.log(level, line, error: error, stackTrace: stackTrace);
    _file?.log(level, line, error: error, stackTrace: stackTrace);
  }
}

/// Shorthand for [AppLogger.instance], e.g. `logger.i('Tag', 'message')`.
final AppLogger logger = AppLogger.instance;
