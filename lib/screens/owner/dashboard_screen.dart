// Owner dashboard — today strip (count, mix, cash) + live visit table.
// Optimized for desktop/web and responsive mobile layouts.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../services/providers.dart';
import '../../widgets/payment_method_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(firestoreServiceProvider);
    final today = DateTime.now();
    final todayStream = svc.visitsForDay(today);

    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: WashTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_car_wash_rounded,
                    color: WashTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'LUXURY ',
                          style: TextStyle(
                            color: WashTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'CAR CARE',
                          style: TextStyle(
                            color: WashTheme.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (MediaQuery.of(context).size.width > 480) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: WashTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: WashTheme.success
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor: WashTheme.success,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: WashTheme.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (MediaQuery.of(context).size.width > 480)
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(today),
                        style: const TextStyle(
                          fontSize: 12,
                          color: WashTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (MediaQuery.of(context).size.width > 600) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Reports'),
                    style: TextButton.styleFrom(
                      foregroundColor: WashTheme.textSecondary,
                    ),
                    onPressed: () => context.push('/owner/reports'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Rates'),
                    style: TextButton.styleFrom(
                      foregroundColor: WashTheme.textSecondary,
                    ),
                    onPressed: () => context.push('/owner/rates'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ] else ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu_rounded),
                    color: WashTheme.surfaceCard,
                    tooltip: 'Menu',
                    onSelected: (val) async {
                      if (val == 'reports') context.push('/owner/reports');
                      if (val == 'rates') context.push('/owner/rates');
                      if (val == 'logout') {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) context.go('/login');
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'reports',
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 18),
                            SizedBox(width: 12),
                            Text('Reports'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rates',
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18),
                            SizedBox(width: 12),
                            Text('Wash Rates'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18),
                            SizedBox(width: 12),
                            Text('Sign Out'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Visit>>(
        stream: todayStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: WashTheme.accent),
            );
          }

          final allVisits = snap.data ?? [];
          final visits = _searchQuery.trim().isEmpty
              ? allVisits
              : allVisits
                  .where((v) =>
                      v.plate.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (v.phone ?? '').contains(_searchQuery))
                  .toList();

          final breakdown = computeRevenueBreakdown(allVisits);
          final totalRevenue = breakdown.total;
          final cashRevenue = breakdown.cash;
          final upiRevenue = breakdown.upi;
          final unknownRevenue = breakdown.unknown;
          final pendingRevenue = breakdown.pending;
          final countByType = <String, int>{};
          for (final v in allVisits) {
            countByType[v.vehicleType] = (countByType[v.vehicleType] ?? 0) + 1;
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: CustomScrollView(
                slivers: [
                  // ── Hero KPI & Metrics ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Revenue Banner Card
                          LayoutBuilder(builder: (context, bc) {
                            final narrow = bc.maxWidth < 480;
                            final revenueFont = narrow ? 36.0 : 46.0;
                            final closeDayBtn = ElevatedButton.icon(
                              onPressed: () => _closeDay(context, ref),
                              icon: const Icon(
                                  Icons.mark_email_read_outlined, size: 16),
                              label: const Text('Close Day'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    WashTheme.accent.withValues(alpha: 0.15),
                                foregroundColor: WashTheme.accent,
                                elevation: 0,
                                minimumSize: Size(narrow ? double.infinity : 0, 38),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                side: BorderSide(
                                    color:
                                        WashTheme.accent.withValues(alpha: 0.3)),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            );
                            return Container(
                              padding: EdgeInsets.all(narrow ? 20 : 28),
                              decoration: BoxDecoration(
                                color: WashTheme.surfaceCard,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: WashTheme.border),
                                gradient: LinearGradient(
                                  colors: [
                                    WashTheme.surfaceCard,
                                    WashTheme.surfaceHigh.withValues(alpha: 0.6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TODAY\'S REVENUE',
                                        style: TextStyle(
                                          color: WashTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      if (!narrow) closeDayBtn,
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹$totalRevenue',
                                        style: TextStyle(
                                          color: WashTheme.accent,
                                          fontSize: revenueFont,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          'across ${allVisits.length} wash${allVisits.length == 1 ? '' : 'es'}',
                                          style: const TextStyle(
                                            color: WashTheme.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label: 'Cash',
                                        amount: '₹$cashRevenue',
                                        color: WashTheme.success,
                                      ),
                                      _StatusPill(
                                        label: 'UPI',
                                        amount: '₹$upiRevenue',
                                        color: WashTheme.accent,
                                      ),
                                      if (unknownRevenue > 0)
                                        _StatusPill(
                                          label: 'Unknown',
                                          amount: '₹$unknownRevenue',
                                          color: WashTheme.textSecondary,
                                        ),
                                      _StatusPill(
                                        label: 'Pending',
                                        amount: '₹$pendingRevenue',
                                        color: pendingRevenue > 0
                                            ? WashTheme.danger
                                            : WashTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                  if (narrow) ...[
                                    const SizedBox(height: 16),
                                    closeDayBtn,
                                  ],
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),

                          // Vehicle breakdown chips
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 600;
                              if (isNarrow) {
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _TypeMetricCard(
                                      label: 'Hatch / Sedan',
                                      count: countByType[VehicleType.hatchSedan] ?? 0,
                                      icon: Icons.directions_car_filled_rounded,
                                      width: (constraints.maxWidth - 10) / 2,
                                    ),
                                    _TypeMetricCard(
                                      label: 'SUV / Compact',
                                      count: countByType[VehicleType.suv] ?? 0,
                                      icon: Icons.airport_shuttle_rounded,
                                      width: (constraints.maxWidth - 10) / 2,
                                    ),
                                    _TypeMetricCard(
                                      label: 'Two Wheeler',
                                      count: countByType[VehicleType.bike] ?? 0,
                                      icon: Icons.two_wheeler_rounded,
                                      width: (constraints.maxWidth - 10) / 2,
                                    ),
                                    _TypeMetricCard(
                                      label: 'Total Washed',
                                      count: allVisits.length,
                                      icon: Icons.local_car_wash_rounded,
                                      width: (constraints.maxWidth - 10) / 2,
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    child: _TypeMetricCard(
                                      label: 'Hatch / Sedan',
                                      count: countByType[VehicleType.hatchSedan] ?? 0,
                                      icon: Icons.directions_car_filled_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TypeMetricCard(
                                      label: 'SUV / Compact',
                                      count: countByType[VehicleType.suv] ?? 0,
                                      icon: Icons.airport_shuttle_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TypeMetricCard(
                                      label: 'Two Wheeler',
                                      count: countByType[VehicleType.bike] ?? 0,
                                      icon: Icons.two_wheeler_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TypeMetricCard(
                                      label: 'Total Washed',
                                      count: allVisits.length,
                                      icon: Icons.local_car_wash_rounded,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // Search & Filter header
                          LayoutBuilder(builder: (context, bc) {
                            final narrow = bc.maxWidth < 540;
                            final searchField = TextField(
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search plate or phone…',
                                hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: WashTheme.textMuted),
                                prefixIcon: const Icon(Icons.search,
                                    size: 18,
                                    color: WashTheme.textSecondary),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                fillColor: WashTheme.surfaceCard,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: WashTheme.border),
                                ),
                              ),
                            );
                            if (narrow) {
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Live Log (${visits.length})',
                                    style: const TextStyle(
                                      color: WashTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(height: 40, child: searchField),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Text(
                                  'Live Vehicle Log (${visits.length})',
                                  style: const TextStyle(
                                    color: WashTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                    width: 240,
                                    height: 40,
                                    child: searchField),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // ── Visit List ─────────────────────────────────────────────
                  if (visits.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: WashTheme.surfaceHigh,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: WashTheme.border),
                                ),
                                child: const Icon(Icons.no_crash_rounded,
                                    size: 36, color: WashTheme.textMuted),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No vehicles logged today yet'
                                    : 'No matching records for "$_searchQuery"',
                                style: const TextStyle(
                                  color: WashTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Vehicle scans logged by workers will stream here instantly.',
                                style: TextStyle(
                                  color: WashTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _VisitTile(visit: visits[i]),
                          childCount: visits.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _closeDay(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WashTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Close Day & Send Email?'),
        content: const Text(
          'This triggers the automated end-of-day summary email to all configured owner email addresses with today\'s complete breakdown.',
          style: TextStyle(color: WashTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: WashTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 44),
            ),
            child: const Text('Send Report'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).triggerCloseDayEmail();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: WashTheme.success, size: 20),
                SizedBox(width: 10),
                Text('Report queued! Check your inbox shortly.'),
              ],
            ),
            backgroundColor: WashTheme.surfaceHigh,
          ),
        );
      }
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            amount,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TypeMetricCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final double? width;

  const _TypeMetricCard({
    required this.label,
    required this.count,
    required this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WashTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WashTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: WashTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, size: 18, color: WashTheme.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count.toString(),
            style: const TextStyle(
              color: WashTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTile extends ConsumerWidget {
  final Visit visit;
  const _VisitTile({required this.visit});

  Future<void> _togglePaid(BuildContext context, WidgetRef ref) async {
    final newPaid = !visit.paid;

    if (newPaid) {
      final method = await showPaymentMethodDialog(
        context,
        subtitle: 'Plate ${visit.plate} — ₹${visit.amount}',
      );
      if (method == null) return;

      try {
        await ref.read(firestoreServiceProvider).updateVisit(visit.id, {
          'paid': true,
          'paymentMethod': method,
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not update payment: $e'),
              backgroundColor: WashTheme.danger,
            ),
          );
        }
      }
      return;
    }

    try {
      await ref.read(firestoreServiceProvider).updateVisit(visit.id, {
        'paid': false,
        'paymentMethod': null,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update payment: $e'),
            backgroundColor: WashTheme.danger,
          ),
        );
      }
    }
  }

  String _paidBadgeLabel() {
    if (!visit.paid) return 'UNPAID';
    if (visit.paymentMethod == PaymentMethod.cash) return 'PAID · CASH';
    if (visit.paymentMethod == PaymentMethod.upi) return 'PAID · UPI';
    return 'PAID';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('h:mm a').format(visit.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: WashTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/owner/visit/${visit.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WashTheme.border),
            ),
            child: LayoutBuilder(builder: (context, bc) {
              final narrow = bc.maxWidth < 400;

              // ── Plate badge ─────────────────────────────────────────
              final plateBadge = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: WashTheme.plateYellow,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: WashTheme.plateBlack, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: WashTheme.plateBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'IND',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      visit.plate,
                      style: const TextStyle(
                        color: WashTheme.plateBlack,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              );

              // ── Price + paid badge ───────────────────────────────────
              final priceCol = Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _togglePaid(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                            _paidBadgeLabel(),
                            style: TextStyle(
                              color: visit.paid
                                  ? WashTheme.success
                                  : WashTheme.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: WashTheme.textMuted, size: 20),
                ],
              );

              // ── Details text ─────────────────────────────────────────
              final detailsText = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        VehicleType.emoji(visit.vehicleType),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${VehicleType.label(visit.vehicleType)} · ${WashPackage.label(visit.packageId)}',
                          style: const TextStyle(
                            color: WashTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          color: WashTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (visit.phone != null &&
                          visit.phone!.isNotEmpty) ...[
                        const Text('·',
                            style: TextStyle(
                                color: WashTheme.textMuted,
                                fontSize: 12)),
                        Text(
                          visit.phone!,
                          style: const TextStyle(
                            color: WashTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );

              if (narrow) {
                // Two-row layout for small phones
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        plateBadge,
                        priceCol,
                      ],
                    ),
                    const SizedBox(height: 10),
                    detailsText,
                  ],
                );
              }

              // Wide layout — single row
              return Row(
                children: [
                  plateBadge,
                  const SizedBox(width: 14),
                  Expanded(child: detailsText),
                  const SizedBox(width: 12),
                  priceCol,
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
