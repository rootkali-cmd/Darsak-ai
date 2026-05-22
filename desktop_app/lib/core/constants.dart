class AppConstants {
  static const String apiBaseUrl = 'http://localhost:8000/api';
  static const String appName = 'DarsakAI Desktop';
  static const String appVersion = '1.0.0';
}

class LocalSyncConfig {
  static String syncIp = '127.0.0.1';
  static int port = 8765;
  static String get uri => 'ws://$syncIp:$port/ws';
  static String deviceId = 'desktop_${DateTime.now().millisecondsSinceEpoch}';
  static const String serviceType = '_darsak-sync._tcp';
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration maxReconnectDelay = Duration(seconds: 30);
}
