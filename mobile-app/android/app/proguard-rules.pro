# Flutter specific
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive
-keep class com.hive.** { *; }

# Keep model classes for JSON serialization
-keep class com.darsak.darsak_mobile.models.** { *; }

# Dio
-keep class com.dio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
