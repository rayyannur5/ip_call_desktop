import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

class AdminWebViewDialog extends StatefulWidget {
  const AdminWebViewDialog({super.key});

  @override
  State<AdminWebViewDialog> createState() => _AdminWebViewDialogState();
}

class _AdminWebViewDialogState extends State<AdminWebViewDialog> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Banner Notification State
  String? _bannerMessage;
  Color _bannerColor = Colors.green;
  IconData _bannerIcon = Icons.check_circle;
  Timer? _bannerTimer;

  void _showBanner(String message, {required Color color, required IconData icon, int durationSeconds = 5}) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerMessage = message;
      _bannerColor = color;
      _bannerIcon = icon;
    });
    _bannerTimer = Timer(Duration(seconds: durationSeconds), () {
      if (mounted) {
        setState(() {
          _bannerMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    try {
      _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    // Reset focus to root scope to regain keyboard focus from native webview
    FocusManager.instance.rootScope.requestFocus();
    
    // Force OS window focus back to Flutter app after the native view is completely removed
    Future.delayed(const Duration(milliseconds: 200), () async {
      try {
        await const MethodChannel('my_app/focus_helper').invokeMethod('grabFocus');
        await windowManager.blur();
        await windowManager.focus();
      } catch (e) {
        debugPrint('Error resetting window focus: $e');
      }
    });
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('DEBUG_LOG: onNavigationRequest url: $url');
            
            if (_isDownloadUrl(url)) {
              _downloadFile(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost/ip-call/'));
  }

  bool _isDownloadUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.xlsx') ||
        lowerUrl.endsWith('.xls') ||
        lowerUrl.endsWith('.csv') ||
        lowerUrl.contains('download') ||
        lowerUrl.contains('export') ||
        lowerUrl.contains('excel');
  }

  Future<String?> _findUsbDrivePath() async {
    if (Platform.isLinux) {
      final user = Platform.environment['USER'] ?? 'parallels';
      final mediaDir = Directory('/media/$user');
      if (await mediaDir.exists()) {
        final List<FileSystemEntity> entities = await mediaDir.list().toList();
        final directories = entities.whereType<Directory>().toList();
        if (directories.isNotEmpty) {
          return directories.first.path;
        }
      }
    } else if (Platform.isWindows) {
      try {
        final result = await Process.run('wmic', ['logicaldisk', 'where', 'drivetype=2', 'get', 'deviceid']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          final lines = output.split('\n').map((l) => l.trim()).toList();
          for (final line in lines) {
            if (line.isNotEmpty && line != 'DeviceID' && RegExp(r'^[A-Z]:').hasMatch(line)) {
              return '$line\\';
            }
          }
        }
      } catch (e) {
        debugPrint('Error detecting USB drive on Windows: $e');
      }
    }
    return null;
  }

  Future<void> _downloadFile(String url) async {
    try {
      debugPrint('DEBUG_LOG: Intercepted download URL: $url');
      setState(() {
        _isLoading = true;
      });

      // Check if USB drive is attached
      final usbPath = await _findUsbDrivePath();
      if (usbPath == null) {
        debugPrint('DEBUG_LOG: Download cancelled - No USB drive found');
        _showBanner(
          'Silakan pasang Flashdisk (USB Drive) terlebih dahulu.',
          color: Colors.orange.withOpacity(0.9),
          icon: Icons.warning,
        );
        return;
      }

      debugPrint('DEBUG_LOG: USB drive detected at: $usbPath');

      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String filename = 'ip-call-export.xlsx';
        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null && contentDisposition.contains('filename=')) {
          final regExp = RegExp(r'filename="?([^";\n\r]+)"?');
          final match = regExp.firstMatch(contentDisposition);
          if (match != null && match.groupCount >= 1) {
            filename = match.group(1)!;
          }
        } else {
          final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
          if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
            filename = lastSegment;
          }
        }

        final savePath = p.join(usbPath, filename);
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('DEBUG_LOG: File downloaded and saved to USB: $savePath');
        
        _showBanner(
          'Download Berhasil! File disimpan di Flashdisk: $filename',
          color: Colors.green.withOpacity(0.9),
          icon: Icons.check_circle,
        );
      } else {
        debugPrint('DEBUG_LOG: Failed HTTP response: ${response.statusCode}');
        _showBanner(
          'Download Gagal: Server mengembalikan status ${response.statusCode}',
          color: Colors.red.withOpacity(0.9),
          icon: Icons.error,
        );
      }
    } catch (e) {
      debugPrint('DEBUG_LOG: Error downloading: $e');
      _showBanner(
        'Download Error: Gagal mengunduh file: $e',
        color: Colors.red.withOpacity(0.9),
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.9,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _controller.reload(),
                          tooltip: 'Refresh Halaman',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // In-dialog Notification Banner
              if (_bannerMessage != null)
                Container(
                  width: double.infinity,
                  color: _bannerColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_bannerIcon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _bannerMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => setState(() => _bannerMessage = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1, thickness: 1),
              // Webview content area
              Expanded(
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
