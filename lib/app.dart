// Top-level MaterialApp with theme and go_router.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class WashLogApp extends ConsumerWidget {
  const WashLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'WashLog',
      debugShowCheckedModeBanner: false,
      theme: WashTheme.dark(),
      routerConfig: router,
    );
  }
}
