class AppConstants {
  static const String apiBaseUrl = 'https://darsak-backend.fly.dev/api';
  static const String appVersion = '2.0.0';
  static const String platformName = 'desktop';
  static const String downloadBaseUrl = 'https://darsak-backend.fly.dev/api/download';
  static const String repositoryUrl = 'https://github.com/rootkali-cmd/Darsak-ai';

  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 20;
  static const int maxSyncRetries = 5;
  static const int maxReconnectDelay = 120;
  static const int maxBackups = 10;
  static const int backupRetentionDays = 14;
  static const int maxSyncOpsHistory = 200;
  static const int analyticsMaxQueueSize = 200;
  static const int maxInstallAttempts = 3;
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

class DbConstants {
  static const String studentsTable = 'students';
  static const String groupsTable = 'groups_tbl';
  static const String attendanceTable = 'attendance';
  static const String gradesTable = 'grades';
  static const String invoicesTable = 'invoices';
  static const String paymentsTable = 'payments';
  static const String syncQueueTable = 'sync_queue';
  static const String deadLetterTable = 'dead_letter';
  static const String syncCursorsTable = 'sync_cursors';
  static const String settingsTable = 'settings';
  static const String conflictLogsTable = 'conflict_logs';
  static const String examsTable = 'exams';
  static const String examQuestionsTable = 'exam_questions';
  static const String examResultsTable = 'exam_results';
}

class PrefKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String onboardingSubjects = 'onboarding_subjects';
  static const String onboardingLevels = 'onboarding_levels';
  static const String cachedUserId = 'cached_user_id';
  static const String cachedUserName = 'cached_user_name';
  static const String cachedUserEmail = 'cached_user_email';
  static const String cachedUserRole = 'cached_user_role';
  static const String cachedUserCode = 'cached_user_code';
  static const String cachedUserIsActive = 'cached_user_is_active';
  static const String cachedUserCreatedAt = 'cached_user_created_at';
  static const String subscriptionData = 'subscription_data';
  static const String analyticsEnabled = 'analytics_enabled';
  static const String updateChannel = 'update_channel';
  static const String ignoredUpdateVersion = 'ignored_update_version';
  static const String lastInstalledVersion = 'last_installed_version';
  static const String remoteConfigCache = 'remote_config_cache';
  static const String lastSyncTime = 'last_sync_time';
}
