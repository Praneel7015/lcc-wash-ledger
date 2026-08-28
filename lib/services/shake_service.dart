// Shake service — starts/stops the native Android foreground service.
// Uses a MethodChannel to communicate with ShakeForegroundService.kt.
// On non-Android platforms (web, etc.), provides a no-op stub.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShakeService {
  static const _channel = MethodChannel('com.washlog.app/shake');

  Future<void> startService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('startShakeService');
    } on PlatformException catch (e) {
      debugPrint('ShakeService start error: $e');
    }
  }

  Future<void> stopService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stopShakeService');
    } on PlatformException catch (e) {
      debugPrint('ShakeService stop error: $e');
    }
  }
}
