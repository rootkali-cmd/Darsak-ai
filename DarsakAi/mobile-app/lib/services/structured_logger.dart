import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';

enum LogSeverity { debug, info, warning, error, critical }

class StructuredLogger {
  StructuredLogger._();
  static final StructuredLogger _instance = StructuredLogger._();
  static StructuredLogger get instance => _instance;

  IOSink? _fileSink;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final date = DateTime.now().toUtc().toIso8601String().split('T').first;
      final file = File('${logDir.path}/app-$date.log');
      _fileSink = file.openWrite(mode: FileMode.append);
    } catch (_) {}
  }

  void _log(LogSeverity severity, String event, {Map<String, dynamic>? data}) {
    final entry = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      'severity': severity.name,
      'platform': 'android',
      'version': AppConstants.appVersion,
      if (data != null) 'data': data,
    };

    final line = jsonEncode(entry) + '\n';

    try {
      _fileSink?.write(line);
    } catch (_) {}
  }

  void info(String event, {Map<String, dynamic>? data}) => _log(LogSeverity.info, event, data: data);
  void warning(String event, {Map<String, dynamic>? data}) => _log(LogSeverity.warning, event, data: data);
  void error(String event, {Map<String, dynamic>? data}) => _log(LogSeverity.error, event, data: data);
  void critical(String event, {Map<String, dynamic>? data}) => _log(LogSeverity.critical, event, data: data);

  void dispose() {
    _fileSink?.flush();
    _fileSink?.close();
  }
}
