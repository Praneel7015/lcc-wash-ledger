// Owner dashboard — today strip (count, mix, cash) + live visit table.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../services/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(firestoreServiceProvider);
    final today = DateTime.now();
    final todayStream = svc.visitsForDay(today);

    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WashLog'),
            Text(
              DateFormat('EEEE, d MMM').format(today),
              style: const TextStyle(
                  fontSize: 13,
                  color: WashTheme.textSecondary,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Reports',
            onPressed: () => context.push('/owner/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.price_change_outlined),
            tooltip: 'Rates',
            onPressed: () => context.push('/owner/rates'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/owner/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Visit>>(
        stream: todayStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: WashTheme.accent));
          }
          final visits = snap.data ?? [];
          final totalRevenue = visits.fold<int>(0, (s, v) => s + v.amount);
          final paidRevenue =
              visits.where((v) => v.paid).fold<int>(0, (s, v) => s + v.amount);
          final countByType = <String, int>{};
          for (final v in visits) {
            countByType[v.vehicleType] =
                (countByType[v.vehicleType] ?? 0) + 1;
          }

          return CustomScrollView(
            slivers: [
              // ── KPI strip ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      // Big money number
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: WashTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WashTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Today\'s revenue',
                                style: TextStyle(
                                    color: WashTheme.textSecondary,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              '₹$totalRevenue',
                              style: const TextStyle(
                                color: WashTheme.accent,
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹$paidRevenue collected  ·  ₹${totalRevenue - paidRevenue} pending',
                              style: const TextStyle(
                                  color: WashTheme.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Type mix chips
                      Row(
                        children: [
                          _KpiChip(
                            label: 'Total',
                            value: visits.length.toString(),
                            icon: Icons.local_car_wash,
                          ),
                          const SizedBox(width: 8),
                          _KpiChip(
                            label: VehicleType.label(VehicleType.hatchSedan),
                            value: (countByType[VehicleType.hatchSedan] ?? 0)
                                .toString(),
                            icon: Icons.directions_car,
                          ),
                          const SizedBox(width: 8),
                          _KpiChip(
                            label: VehicleType.label(VehicleType.suv),
                            value:
                                (countByType[VehicleType.suv] ?? 0).toString(),
                            icon: Icons.airport_shuttle,
                          ),
                          const SizedBox(width: 8),
                          _KpiChip(
                            label: VehicleType.label(VehicleType.bike),
                            value: (countByType[VehicleType.bike] ?? 0)
                                .toString(),
                            icon: Icons.two_wheeler,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Close day button
                      OutlinedButton.icon(
                        onPressed: () => _closeDay(context, ref),
                        icon: const Icon(Icons.nightlight_round, size: 18),
                        label: const Text('Close day & send report'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: WashTheme.textSecondary,
                          side: const BorderSide(color: WashTheme.border),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Visit list ────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Today\'s vehicles',
                    style: TextStyle(
                      color: WashTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              if (visits.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_car_wash,
                            size: 64, color: WashTheme.border),
                        SizedBox(height: 16),
                        Text('No vehicles yet today',
                            style:
                                TextStyle(color: WashTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _VisitTile(visit: visits[i]),
                    childCount: visits.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _closeDay(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WashTheme.surface,
        title: const Text('Close day?'),
        content: const Text(
          'This will send the end-of-day report to your email.',
          style: TextStyle(color: WashTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send report'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).triggerCloseDayEmail();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report queued — check your email shortly.')),
        );
      }
    }
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: WashTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WashTheme.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: WashTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: WashTheme.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Visit visit;
  const _VisitTile({required this.visit});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(visit.createdAt);
    return InkWell(
      onTap: () => context.push('/owner/visit/${visit.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WashTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WashTheme.border),
        ),
        child: Row(
          children: [
            // Plate badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: WashTheme.plateYellow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: WashTheme.plateBlack, width: 1.5),
              ),
              child: Text(
                visit.plate,
                style: const TextStyle(
                  color: WashTheme.plateBlack,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${VehicleType.label(visit.vehicleType)}  ·  ${WashPackage.label(visit.packageId)}',
                    style: const TextStyle(
                        color: WashTheme.textPrimary, fontSize: 14),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                        color: WashTheme.textSecondary, fontSize: 12),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: visit.paid
                        ? WashTheme.success.withOpacity(0.15)
                        : WashTheme.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    visit.paid ? 'Paid' : 'Unpaid',
                    style: TextStyle(
                      color:
                          visit.paid ? WashTheme.success : WashTheme.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
