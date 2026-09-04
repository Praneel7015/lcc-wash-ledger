// Top-level MaterialApp with theme and go_router.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';

class WashLogApp extends ConsumerWidget {
  const WashLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Luxury Car Care',
      debugShowCheckedModeBanner: false,
      theme: WashTheme.light(),
      darkTheme: WashTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
