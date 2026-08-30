// Worker's today washes list — view and mark unpaid washes as paid later.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../services/providers.dart';
import '../../widgets/worker_app_bar.dart';

class TodayWashesScreen extends ConsumerWidget {
  const TodayWashesScreen({super.key});

  Future<void> _togglePaid(
    BuildContext context,
    WidgetRef ref,
    Visit visit,
  ) async {
    final newPaid = !visit.paid;
    final action = newPaid ? 'mark as PAID' : 'mark as UNPAID';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WashTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${newPaid ? 'Mark paid' : 'Mark unpaid'}?'),
        content: Text(
          'Plate ${formatIndianPlate(visit.plate)} — ₹${visit.amount}\n\n'
          'This will $action for today\'s record.',
          style: const TextStyle(color: WashTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: WashTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(newPaid ? 'Mark paid' : 'Mark unpaid'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(firestoreServiceProvider)
          .updateVisit(visit.id, {'paid': newPaid});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${formatIndianPlate(visit.plate)} marked ${newPaid ? 'paid' : 'unpaid'}',
            ),
            backgroundColor: WashTheme.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: WashTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(firestoreServiceProvider);
    final todayStream = svc.visitsForDay(DateTime.now());
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: const WorkerAppBar(title: "Today's washes"),
      body: StreamBuilder<List<Visit>>(
        stream: todayStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: WashTheme.accent),
            );
          }

          final visits = snap.data ?? [];
          final unpaid = visits.where((v) => !v.paid).length;

          if (visits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_car_wash_outlined,
                        size: 48, color: WashTheme.textMuted),
                    SizedBox(height: 16),
                    Text(
                      'No washes logged today yet',
                      style: TextStyle(
                        color: WashTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${visits.length} wash${visits.length == 1 ? '' : 'es'} today',
                      style: const TextStyle(
                        color: WashTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (unpaid > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: WashTheme.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  WashTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$unpaid unpaid',
                          style: const TextStyle(
                            color: WashTheme.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tap payment status to update when customer pays later',
                  style: TextStyle(color: WashTheme.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: visits.length,
                  itemBuilder: (context, i) {
                    final visit = visits[i];
                    return _TodayWashTile(
                      visit: visit,
                      time: timeFmt.format(visit.createdAt),
                      onTogglePaid: () => _togglePaid(context, ref, visit),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayWashTile extends StatelessWidget {
  final Visit visit;
  final String time;
  final VoidCallback onTogglePaid;

  const _TodayWashTile({
    required this.visit,
    required this.time,
    required this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WashTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WashTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatIndianPlate(visit.plate),
                  style: const TextStyle(
                    color: WashTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${VehicleType.label(visit.vehicleType)} · ${WashPackage.label(visit.packageId)}',
                  style: const TextStyle(
                    color: WashTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: WashTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${visit.amount}',
                style: const TextStyle(
                  color: WashTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onTogglePaid,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: visit.paid
                        ? WashTheme.success.withValues(alpha: 0.15)
                        : WashTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: visit.paid
                          ? WashTheme.success.withValues(alpha: 0.3)
                          : WashTheme.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    visit.paid ? 'PAID' : 'UNPAID',
                    style: TextStyle(
                      color:
                          visit.paid ? WashTheme.success : WashTheme.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
