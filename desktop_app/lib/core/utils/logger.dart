import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';

enum LogSeverity { debug, info, warning, error, critical }

final class AppLogger {
  AppLogger._();
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  IOSink? _fileSink;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) await logDir.create(recursive: true);
      final date = DateTime.now().toUtc().toIso8601String().split('T').first;
      final file = File('${logDir.path}/app-$date.log');
      _fileSink = file.openWrite(mode: FileMode.append);
    } catch (_) {}
  }

  void _log(LogSeverity severity, String event, {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) {
    final entry = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      'severity': severity.name,
      'platform': AppConstants.platformName,
      'version': AppConstants.appVersion,
      if (data != null) 'data': data,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString().split('\n').take(5).join('\n'),
    };
    final line = jsonEncode(entry) + '\n';
    try {
      _fileSink?.write(line);
    } catch (_) {}
  }

  void info(String event, {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) =>
      _log(LogSeverity.info, event, data: data, error: error, stackTrace: stackTrace);
  void warning(String event, {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) =>
      _log(LogSeverity.warning, event, data: data, error: error, stackTrace: stackTrace);
  void error(String event, {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) =>
      _log(LogSeverity.error, event, data: data, error: error, stackTrace: stackTrace);
  void critical(String event, {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) =>
      _log(LogSeverity.critical, event, data: data, error: error, stackTrace: stackTrace);

  void dispose() {
    _fileSink?.flush();
    _fileSink?.close();
  }
}
