import 'package:flutter/foundation.dart';

typedef TokenRefreshCallback = void Function(String newToken);

class FcmService {
  FcmService._();

  static void Function()? onMaintenanceRestored;

  static Future<void> init() async {}

  static Future<String?> getToken() async => null;

  static void onTokenRefresh(TokenRefreshCallback callback) {}
}
