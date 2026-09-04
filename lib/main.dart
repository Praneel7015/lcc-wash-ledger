import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // The status-bar overlay style is set per-theme in WashTheme (AppBarTheme.
  // systemOverlayStyle) so it inverts correctly in light mode. Setting it
  // globally here would pin the icons to white forever.
  runApp(const ProviderScope(child: WashLogApp()));
}
