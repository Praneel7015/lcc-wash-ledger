// Reusable app bar for all worker screens.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import 'theme_toggle_button.dart';

class WorkerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? extraActions;

  const WorkerAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                  fontSize: 13,
                  color: context.wash.textSecondary,
                  fontWeight: FontWeight.w400),
            ),
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        const ThemeToggleButton(),
        IconButton(
          icon: const Icon(Icons.logout, size: 22),
          tooltip: 'Sign out',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
