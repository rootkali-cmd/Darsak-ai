import 'dart:async';

/// No-op debug tracker. All methods are empty.
/// Kept for backward compatibility so existing call sites don't break.
final class DebugTracker {
  DebugTracker._();
  static final DebugTracker instance = DebugTracker._();

  final StreamController<void> _dummyController = StreamController<void>.broadcast();
  Stream<void> get onEvent => _dummyController.stream;
  List<void> get recentEvents => const [];

  bool get enabled => false;
  int get notifyCount => 0;
  int get rebuildCount => 0;
  int get syncEventCount => 0;
  int get apiCallCount => 0;
  int get dbQueryCount => 0;
  Duration get uptime => Duration.zero;

  Future<void> init() async {}
  void notifyListeners(String label) {}
  void widgetRebuild(String widgetName) {}
  void syncEvent(String type, String status, {String? detail}) {}
  void connectivityChange(bool isOnline) {}
  void apiCall(String method, String path, {int? statusCode, int? latencyMs, String? error}) {}
  void dbQuery(String query, {int? rowCount, int? latencyMs}) {}
  void appError(String source, Object error, {StackTrace? stack}) {}
  void providerChange(String providerName, {String? detail}) {}
  void log(String category, String message) {}
  void dispose() {
    _dummyController.close();
  }
}

/// No-op mixin. Does nothing.
mixin DebugMixin<T> {
  void reassemble() {}
  void initState() {}
}
