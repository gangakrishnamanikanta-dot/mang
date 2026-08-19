# Flutter + Supabase + Google Sign-In ProGuard rules

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.**     { *; }
-keep class io.flutter.view.**    { *; }
-keep class io.flutter.**         { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.common.MethodCall { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Obfuscation
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
