// Worker's today washes list — view and mark unpaid washes as paid later.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../providers/package_labels_provider.dart';
import '../../providers/visits_provider.dart';
import '../../services/providers.dart';
import '../../widgets/payment_method_dialog.dart';
import '../../widgets/worker_app_bar.dart';

class TodayWashesScreen extends ConsumerWidget {
  const TodayWashesScreen({super.key});

  Future<void> _togglePaid(
    BuildContext context,
    WidgetRef ref,
    Visit visit,
  ) async {
    final newPaid = !visit.paid;

    if (newPaid) {
      final method = await showPaymentMethodDialog(
        context,
        subtitle:
            'Plate ${formatIndianPlate(visit.plate)} — ₹${visit.amount}',
      );
      if (method == null) return;

      try {
        await ref.read(firestoreServiceProvider).updateVisit(visit.id, {
          'paid': true,
          'paymentMethod': method,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${formatIndianPlate(visit.plate)} marked paid (${PaymentMethod.label(method)})',
              ),
              backgroundColor: context.wash.surfaceHigh,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: context.wash.danger,
            ),
          );
        }
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.wash.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark unpaid?'),
        content: Text(
          'Plate ${formatIndianPlate(visit.plate)} — ₹${visit.amount}\n\n'
          'This will mark the wash as unpaid for today\'s record.',
          style: TextStyle(color: context.wash.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: context.wash.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark unpaid'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(firestoreServiceProvider).updateVisit(visit.id, {
        'paid': false,
        'paymentMethod': null,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${formatIndianPlate(visit.plate)} marked unpaid',
            ),
            backgroundColor: context.wash.surfaceHigh,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: context.wash.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keyed by midnight: `visitsForDay(DateTime.now())` inside build() opened a
    // brand-new Firestore listener on every rebuild.
    final dayKey = startOfDay(DateTime.now());
    final visitsAsync = ref.watch(visitsForDayProvider(dayKey));
    final packageLabels = ref.watch(packageLabelsProvider);
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: context.wash.bg,
      appBar: const WorkerAppBar(title: "Today's washes"),
      body: visitsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.wash.accent),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 44, color: context.wash.danger),
                const SizedBox(height: 14),
                Text(
                  "Couldn't load today's washes",
                  style: TextStyle(
                    color: context.wash.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$err',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.wash.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(visitsForDayProvider(dayKey)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(180, 44)),
                ),
              ],
            ),
          ),
        ),
        data: (visits) {
          final unpaid = visits.where((v) => !v.paid).length;

          if (visits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_car_wash_outlined,
                        size: 48, color: context.wash.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No washes logged today yet',
                      style: TextStyle(
                        color: context.wash.textPrimary,
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
                      style: TextStyle(
                        color: context.wash.textPrimary,
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
                          color: context.wash.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  context.wash.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$unpaid unpaid',
                          style: TextStyle(
                            color: context.wash.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tap payment status to update when customer pays later',
                  style: TextStyle(color: context.wash.textMuted, fontSize: 12),
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
                      packageLabel: resolvePackageLabel(
                          packageLabels, visit.packageId),
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
  final String packageLabel;
  final VoidCallback onTogglePaid;

  const _TodayWashTile({
    required this.visit,
    required this.time,
    required this.packageLabel,
    required this.onTogglePaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.wash.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.wash.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatIndianPlate(visit.plate),
                  style: TextStyle(
                    color: context.wash.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${VehicleType.label(visit.vehicleType)} · $packageLabel',
                  style: TextStyle(
                    color: context.wash.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    color: context.wash.textMuted,
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
                style: TextStyle(
                  color: context.wash.textPrimary,
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
                        ? context.wash.success.withValues(alpha: 0.15)
                        : context.wash.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: visit.paid
                          ? context.wash.success.withValues(alpha: 0.3)
                          : context.wash.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    visit.paid
                        ? (visit.paymentMethod != null
                            ? 'PAID · ${PaymentMethod.label(visit.paymentMethod).toUpperCase()}'
                            : 'PAID')
                        : 'UNPAID',
                    style: TextStyle(
                      color:
                          visit.paid ? context.wash.success : context.wash.danger,
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
