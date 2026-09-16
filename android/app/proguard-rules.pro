# WashLog ProGuard / R8 rules
#
# Flutter's flutter_tools AAR already ships consumer ProGuard rules for the
# Flutter engine itself (keep io.flutter.**). Firebase, Firestore, and most
# Google libraries ship their own consumer rules via AAR. This file only needs
# project-specific additions.

# ── Firebase / Google ─────────────────────────────────────────────────────────
# Keep Firebase custom-claims classes used via reflection in firebase-auth.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# ── Image libraries ───────────────────────────────────────────────────────────
# flutter_image_compress uses native JNI; keep the JNI entry points.
-keep class com.fluttercandies.** { *; }

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ── Suppress notes about missing classes that aren't used at runtime ──────────
-dontnote kotlinx.serialization.**
-dontwarn kotlinx.serialization.**
