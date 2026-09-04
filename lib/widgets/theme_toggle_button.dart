// Light / dark toggle. Drop it into any AppBar `actions` list.
//
// Tap flips between light and dark. Long-press returns to "follow system", so
// the user is never stuck on a manual choice they made once by accident.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  final double size;

  const ThemeToggleButton({super.key, this.size = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tooltip = switch (mode) {
      ThemeMode.system =>
        'Following system theme · tap for ${isDark ? 'light' : 'dark'}',
      ThemeMode.light => 'Light theme · tap for dark, hold for system',
      ThemeMode.dark => 'Dark theme · tap for light, hold for system',
    };

    // GestureDetector wraps the button because IconButton has no onLongPress.
    return GestureDetector(
      onLongPress: mode == ThemeMode.system
          ? null
          : () => ref.read(themeModeProvider.notifier).set(ThemeMode.system),
      child: IconButton(
        tooltip: tooltip,
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggle(currentlyDark: isDark),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey<bool>(isDark),
            size: size,
          ),
        ),
      ),
    );
  }
}
