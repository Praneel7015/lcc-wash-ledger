## WashLog ProGuard / R8 rules
#
# Flutter's flutter_tools AAR already ships consumer ProGuard rules for the
# Flutter engine itself (keep io.flutter.**). Firebase, Firestore, and most
# Google libraries ship their own consumer rules via AAR. This file only needs
# project-specific additions.

# ── Firebase / Google ─────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# ── google_mlkit_text_recognition ────────────────────────────────────────────
# Keep the Flutter plugin bridge and the full ML Kit text recognition API so
# R8 does not strip classes that are only referenced via reflection/JNI at
# runtime (Dart calls into Java via platform channels, not direct references).
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

# Optional language packs (Chinese, Devanagari, Japanese, Korean) are NOT
# bundled with this app — only Latin/English is used for Indian licence plates.
# Suppress the R8 "missing class" errors for their references in the plugin.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ── Image libraries ───────────────────────────────────────────────────────────
-keep class com.fluttercandies.** { *; }

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ── Suppress notes about missing classes that aren't used at runtime ──────────
-dontnote kotlinx.serialization.**
-dontwarn kotlinx.serialization.**
