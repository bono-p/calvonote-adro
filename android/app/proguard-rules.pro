# CalvoNote — ProGuard rules

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# flutter_tts
-keep class it.luan.flutter_tts.** { *; }

# record
-keep class com.llfbandit.record.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata { *; }

# JSON / HTTP
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**
