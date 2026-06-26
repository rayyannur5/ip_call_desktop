import 'package:get/get.dart';
import 'package:mysql_client/mysql_client.dart';
import 'storage_service.dart';
import 'dart:async';

class DatabaseService extends GetxService {
  MySQLConnection? _conn;
  final isConnected = false.obs;
  Future<void>? _connectFuture;
  Timer? _pingTimer;

  Future<void> connect() async {
    if (_connectFuture != null) {
      return _connectFuture;
    }

    final completer = Completer<void>();
    _connectFuture = completer.future;

    try {
      try {
        await _conn?.close();
      } catch (_) {}

      final storage = Get.find<StorageService>();
      _conn = await MySQLConnection.createConnection(
        host: storage.serverHost,
        port: storage.dbPort,
        userName: storage.dbUsername,
        password: storage.dbPassword,
        databaseName: storage.dbName,
        secure: false,
      );
      await _conn!.connect().timeout(const Duration(seconds: 5));
      isConnected.value = true;
      completer.complete();
      _startPingTimer();
    } catch (e) {
      isConnected.value = false;
      completer.completeError(e);
      rethrow;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    try {
      await _conn?.close();
    } catch (_) {}
    _conn = null;
    isConnected.value = false;
  }

  Future<bool> testConnection() async {
    try {
      final storage = Get.find<StorageService>();
      final conn = await MySQLConnection.createConnection(
        host: storage.serverHost,
        port: storage.dbPort,
        userName: storage.dbUsername,
        password: storage.dbPassword,
        databaseName: storage.dbName,
        secure: false,
      );
      await conn.connect().timeout(const Duration(seconds: 5));
      await conn.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _ensureConnected() async {
    if (_conn == null || !_conn!.connected) {
      await connect();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await checkConnectionHealth();
    });
  }

  Future<void> checkConnectionHealth() async {
    if (_conn == null || !_conn!.connected) {
      isConnected.value = false;
      return;
    }
    try {
      // Ping the server using a lightweight query
      await _conn!.execute('SELECT 1').timeout(const Duration(seconds: 3));
      isConnected.value = _conn!.connected;
    } catch (_) {
      isConnected.value = false;
    }
  }

  /// Self-healing query wrapper: checks connection and retries once on failure.
  /// Ignores reconnect retry for programming errors (like CastError) to prevent infinite loops.
  Future<T> _executeSafe<T>(Future<T> Function() queryBlock) async {
    await _ensureConnected();
    try {
      return await queryBlock();
    } catch (e) {
      if (e is TypeError || e.toString().contains('is not a subtype of type')) {
        print('Database query programming error: $e');
        rethrow;
      }

      print('Database query failed: $e. Reconnecting...');
      try {
        await connect();
        return await queryBlock();
      } catch (retryException) {
        print('Database retry failed: $retryException');
        rethrow;
      }
    }
  }

  // ---- Bed ----

  Future<List<Map<String, dynamic>>> getAllBeds() async {
    return _executeSafe(() async {
      final result = await _conn!.execute('SELECT * FROM bed');
      return result.rows.map((r) => r.typedAssoc()).toList();
    });
  }

  Future<Map<String, dynamic>?> getBedById(String id) async {
    return _executeSafe(() async {
      final result = await _conn!.execute(
        'SELECT * FROM bed WHERE id = :id',
        {'id': id},
      );
      if (result.rows.isEmpty) return null;
      return result.rows.first.typedAssoc();
    });
  }

  // ---- Toilet ----

  Future<Map<String, dynamic>?> getToiletById(String id) async {
    return _executeSafe(() async {
      final result = await _conn!.execute(
        'SELECT * FROM toilet WHERE id = :id',
        {'id': id},
      );
      if (result.rows.isEmpty) return null;
      return result.rows.first.typedAssoc();
    });
  }

  // ---- Room ----

  Future<Map<String, dynamic>?> getRoomById(String id) async {
    return _executeSafe(() async {
      final result = await _conn!.execute(
        'SELECT * FROM room WHERE id = :id',
        {'id': id},
      );
      if (result.rows.isEmpty) return null;
      return result.rows.first.typedAssoc();
    });
  }

  // ---- Devices grouped by room ----

  Future<List<Map<String, dynamic>>> getDevicesGroupedByRoom() async {
    return _executeSafe(() async {
      // Get all rooms
      final roomResult = await _conn!.execute('SELECT * FROM room');
      final rooms = roomResult.rows.map((r) => r.typedAssoc()).toList();

      // Get all beds
      final bedResult = await _conn!.execute('SELECT * FROM bed');
      final beds = bedResult.rows.map((r) => r.typedAssoc()).toList();

      // Get all toilets
      final toiletResult = await _conn!.execute('SELECT * FROM toilet');
      final toilets = toiletResult.rows.map((r) => r.typedAssoc()).toList();

      List<Map<String, dynamic>> grouped = [];

      for (final room in rooms) {
        final roomId = room['id']?.toString();
        List<Map<String, dynamic>> devices = [];

        // Add beds belonging to this room
        for (final bed in beds) {
          if (bed['room_id']?.toString() == roomId) {
            devices.add({
              ...bed,
              'active': (bed['bypass']?.toString() == '1'),
              'message': 'c',
              'timeout': null,
            });
          }
        }

        // Add toilets belonging to this room
        for (final toilet in toilets) {
          if (toilet['room_id']?.toString() == roomId) {
            devices.add({
              ...toilet,
              'mic': null,
              'tw': '0',
              'active': (toilet['bypass']?.toString() == '1'),
              'message': 'c',
              'timeout': null,
            });
          }
        }

        if (devices.isNotEmpty) {
          grouped.add({
            'id': room['id'],
            'name': room['name'] ?? '',
            'device': devices,
          });
        }
      }

      return grouped;
    });
  }

  // Devices with tw=1 (2-way), for contact list
  Future<List<Map<String, dynamic>>> getDevices2Way() async {
    return _executeSafe(() async {
      final roomResult = await _conn!.execute('SELECT * FROM room');
      final rooms = roomResult.rows.map((r) => r.typedAssoc()).toList();

      final bedResult = await _conn!.execute('SELECT * FROM bed');
      final beds = bedResult.rows.map((r) => r.typedAssoc()).toList();

      List<Map<String, dynamic>> grouped = [];

      for (final room in rooms) {
        final roomId = room['id']?.toString();
        List<Map<String, dynamic>> devices = [];

        for (final bed in beds) {
          if (bed['room_id']?.toString() == roomId) {
            devices.add({
              ...bed,
              'active': false,
              'message': 'c',
              'timeout': null,
            });
          }
        }

        if (devices.isNotEmpty) {
          grouped.add({
            'id': room['id'],
            'name': room['name'] ?? '',
            'device': devices,
          });
        }
      }

      return grouped;
    });
  }

  // ---- Utils ----

  Future<Map<String, double>> getUtils() async {
    return _executeSafe(() async {
      final result = await _conn!.execute('SELECT * FROM utils');
      Map<String, double> utils = {};
      for (final row in result.rows) {
        final assoc = row.typedAssoc();
        final typeVal = assoc['type'];
        final valObj = assoc['value'];
        double finalVal = 0.0;
        if (valObj is num) {
          finalVal = valObj.toDouble();
        } else if (valObj != null) {
          finalVal = double.tryParse(valObj.toString()) ?? 0.0;
        }
        utils[typeVal?.toString() ?? ''] = finalVal;
      }
      return utils;
    });
  }

  // ---- MasterSound ----

  Future<List<Map<String, dynamic>>> getMasterSounds() async {
    return _executeSafe(() async {
      final result = await _conn!.execute('SELECT * FROM mastersound');
      return result.rows.map((r) => r.typedAssoc()).toList();
    });
  }

  // ---- History ----

  Future<List<Map<String, dynamic>>> getHistoryByDate(String date) async {
    return _executeSafe(() async {
      final result = await _conn!.execute(
        '''SELECT h.*, ch.name as category_name, b.username, b.phone 
           FROM history h 
           JOIN category_history ch ON h.category_history_id = ch.id 
           LEFT JOIN bed b ON b.id = h.bed_id 
           WHERE DATE(h.timestamp) = :date 
           ORDER BY h.timestamp DESC''',
        {'date': date},
      );
      return result.rows.map((r) => r.typedAssoc()).toList();
    });
  }

  Future<void> createHistory(String bedId, int categoryHistoryId,
      {String? duration}) async {
    await _executeSafe(() async {
      await _conn!.execute(
        '''INSERT INTO history (bed_id, category_history_id, duration, timestamp) 
           VALUES (:bed_id, :cat, :dur, NOW())''',
        {
          'bed_id': bedId,
          'cat': categoryHistoryId.toString(),
          'dur': duration,
        },
      );
    });
  }

  // ---- Log ----

  Future<List<Map<String, dynamic>>> getLogsByDate(String date) async {
    return _executeSafe(() async {
      final result = await _conn!.execute(
        '''SELECT l.*, cl.name, COALESCE(b.username, t.username) as username 
           FROM log l 
           JOIN category_log cl ON l.category_log_id = cl.id 
           LEFT JOIN bed b ON b.id = l.device_id 
           LEFT JOIN toilet t ON t.id = l.device_id 
           WHERE DATE(l.timestamp) = :date 
           ORDER BY l.timestamp DESC''',
        {'date': date},
      );
      return result.rows.map((r) => r.typedAssoc()).toList();
    });
  }

  /// Category mapping: darurat=1, call=2, blue=3, infus=4, assist=5
  static const Map<String, int> categoryLogMap = {
    'darurat': 1,
    'call': 2,
    'blue': 3,
    'infus': 4,
    'assist': 5,
  };

  Future<void> createLog(String type, String deviceId, int time,
      int nursePresence) async {
    final categoryId = categoryLogMap[type];
    if (categoryId == null) return;
    await _executeSafe(() async {
      await _conn!.execute(
        '''INSERT INTO log (category_log_id, device_id, time, nurse_presence, timestamp) 
           VALUES (:cat, :dev, :time, :np, NOW())''',
        {
          'cat': categoryId.toString(),
          'dev': deviceId,
          'time': time.toString(),
          'np': nursePresence.toString(),
        },
      );
    });
  }

  @override
  void onClose() {
    _pingTimer?.cancel();
    disconnect();
    super.onClose();
  }
}
