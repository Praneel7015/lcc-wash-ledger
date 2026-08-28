// Owner settings: email address, close-day time, shake service controls, sign-out.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() =>
      _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  final _emailCtrl = TextEditingController();
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 30);
  bool _loading = true;
  bool _saving = false;
  bool _closingDay = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = ref.read(firestoreServiceProvider);
    final data = await svc.getSettings();
    if (!mounted) return;
    setState(() {
      _emailCtrl.text = data['ownerEmail'] as String? ?? '';
      _closeTime = TimeOfDay(
        hour: data['closeDayHour'] as int? ?? 21,
        minute: data['closeDayMinute'] as int? ?? 30,
      );
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _feedback = null;
    });
    await ref.read(firestoreServiceProvider).updateSettings({
      'ownerEmail': _emailCtrl.text.trim(),
      'closeDayHour': _closeTime.hour,
      'closeDayMinute': _closeTime.minute,
    });
    if (mounted) setState(() { _saving = false; _feedback = 'Settings saved.'; });
  }

  Future<void> _closeDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WashTheme.surface,
        title: const Text('Send end-of-day report?'),
        content: const Text(
          'A summary email will be sent to your inbox.',
          style: TextStyle(color: WashTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _closingDay = true; _feedback = null; });
    try {
      await FirebaseFirestore.instance.collection('emailTasks').add({
        'type': 'closeDay',
        'date': FieldValue.serverTimestamp(),
        'triggeredBy': FirebaseAuth.instance.currentUser?.uid,
        'manual': true,
        'status': 'pending',
      });
      if (mounted) {
        setState(() => _feedback = 'Report queued — check your inbox shortly.');
      }
    } catch (e) {
      if (mounted) setState(() => _feedback = 'Error: $e');
    } finally {
      if (mounted) setState(() => _closingDay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: WashTheme.accent),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                          color: WashTheme.accent, fontWeight: FontWeight.w700),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: WashTheme.accent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionLabel('Email reports'),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: WashTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Owner email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: WashTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                _Tile(
                  icon: Icons.schedule_rounded,
                  title: 'Auto close-day time',
                  subtitle:
                      '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')} daily',
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _closeTime,
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: WashTheme.accent),
                        ),
                        child: child!,
                      ),
                    );
                    if (t != null) setState(() => _closeTime = t);
                  },
                ),
                const SizedBox(height: 28),
                _SectionLabel('End of day'),
                OutlinedButton.icon(
                  onPressed: _closingDay ? null : _closeDay,
                  icon: _closingDay
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: WashTheme.accent),
                        )
                      : const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Close day & send email now'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52)),
                ),
                const SizedBox(height: 28),
                _SectionLabel('Shake service (workers)'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WashTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: WashTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workers start the shake service at the beginning of their shift. '
                        'While it runs, shaking the phone opens the camera screen immediately.',
                        style: TextStyle(
                            color: WashTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  ref.read(shakeServiceProvider).startService(),
                              icon: const Icon(Icons.vibration_rounded),
                              label: const Text('Start shake'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  ref.read(shakeServiceProvider).stopService(),
                              child: const Text('Stop'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionLabel('Account'),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded,
                      color: WashTheme.danger),
                  label: const Text('Sign out',
                      style: TextStyle(color: WashTheme.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WashTheme.danger),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                if (_feedback != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _feedback!,
                    style: TextStyle(
                      color: _feedback!.startsWith('Error')
                          ? WashTheme.danger
                          : WashTheme.success,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: WashTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WashTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WashTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: WashTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: WashTheme.textPrimary, fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: WashTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WashTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
