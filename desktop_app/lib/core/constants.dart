class AppConstants {
  static const String apiBaseUrl = 'https://darsak-backend.fly.dev/api';
  static const String appName = 'DarsakAI Desktop';
  static const String appVersion = '1.2.0';

  static String get platformName {
    if (const bool.fromEnvironment('is_linux', defaultValue: false)) return 'linux';
    return 'windows';
  }

  static const String downloadBaseUrl = 'https://darsak-backend.fly.dev/api/download';
  static const String repositoryUrl = 'https://github.com/rootkali-cmd/Darsak-ai';
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
