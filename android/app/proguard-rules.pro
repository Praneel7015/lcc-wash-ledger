## WashLog ProGuard / R8 rules
#
# Flutter's flutter_tools AAR already ships consumer ProGuard rules for the
# Flutter engine itself (keep io.flutter.**). Firebase, Firestore, and most
# Google libraries ship their own consumer rules via AAR. This file only needs
# project-specific additions.

# ── Firebase / Google ─────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# ── google_mlkit_text_recognition — optional language packs ───────────────────
# The plugin references Chinese, Devanagari, Japanese, and Korean script
# recogniser classes but they are optional at runtime (only Latin/English is
# used for Indian licence plates). R8 errors on missing classes by default;
# suppress the warnings and keep the classes if they ever do appear on the
# classpath.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# ── Image libraries ───────────────────────────────────────────────────────────
-keep class com.fluttercandies.** { *; }

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ── Suppress notes about missing classes that aren't used at runtime ──────────
-dontnote kotlinx.serialization.**
-dontwarn kotlinx.serialization.**
