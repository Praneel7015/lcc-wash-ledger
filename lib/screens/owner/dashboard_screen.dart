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
import '../../providers/package_labels_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/visits_provider.dart';
import '../../services/providers.dart';
import '../../widgets/payment_method_dialog.dart';
import '../../widgets/theme_toggle_button.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();

  bool get _isToday => _isSameDay(_selectedDate, DateTime.now());

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _goToPrevDay() => setState(() {
        _searchQuery = '';
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      });

  void _goToNextDay() {
    if (_isToday) return;
    setState(() {
      _searchQuery = '';
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _goToToday() => setState(() {
        _searchQuery = '';
        _selectedDate = DateTime.now();
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      // No Theme override — the app theme already styles the picker for both
      // light and dark. Forcing ColorScheme.dark here broke light mode.
    );
    if (picked != null) {
      setState(() {
        _searchQuery = '';
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keyed by midnight so the stream is cached per day instead of being
    // rebuilt (and re-billed) on every keystroke in the search box.
    final dayKey = startOfDay(_selectedDate);
    final visitsAsync = ref.watch(visitsForDayProvider(dayKey));

    return Scaffold(
      backgroundColor: context.wash.bg,
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
                    color: context.wash.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_car_wash_rounded,
                    color: context.wash.accent,
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
                        Text(
                          'LUXURY ',
                          style: TextStyle(
                            color: context.wash.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'CAR CARE',
                          style: TextStyle(
                            color: context.wash.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (MediaQuery.of(context).size.width > 480) ...[
                          const SizedBox(width: 8),
                          if (_isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.wash.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: context.wash.success
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: context.wash.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: context.wash.success,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _goToPrevDay,
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                              color: context.wash.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Text(
                              DateFormat(_isToday
                                      ? 'EEEE, d MMMM yyyy'
                                      : 'EEE, d MMM yyyy')
                                  .format(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: _isToday
                                    ? context.wash.textSecondary
                                    : context.wash.accent,
                                fontWeight: _isToday
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _isToday ? null : _goToNextDay,
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: _isToday
                                  ? context.wash.textMuted
                                  : context.wash.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const Spacer(),
                if (MediaQuery.of(context).size.width > 600) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Reports'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.wash.textSecondary,
                    ),
                    onPressed: () => context.push('/owner/reports'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Rates'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.wash.textSecondary,
                    ),
                    onPressed: () => context.push('/owner/rates'),
                  ),
                  const SizedBox(width: 4),
                  const ThemeToggleButton(size: 20),
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
                    color: context.wash.surfaceCard,
                    tooltip: 'Menu',
                    onSelected: (val) async {
                      if (val == 'reports') context.push('/owner/reports');
                      if (val == 'rates') context.push('/owner/rates');
                      if (val == 'theme') {
                        ref.read(themeModeProvider.notifier).toggle(
                              currentlyDark: Theme.of(context).brightness ==
                                  Brightness.dark,
                            );
                      }
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
                      PopupMenuItem(
                        value: 'theme',
                        child: Row(
                          children: [
                            Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              Theme.of(context).brightness == Brightness.dark
                                  ? 'Light Theme'
                                  : 'Dark Theme',
                            ),
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
      body: visitsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.wash.accent),
        ),
        // Previously a failed query fell through to `snap.data ?? []` and the
        // dashboard silently showed zero revenue. Surface it instead.
        error: (err, _) => _DashboardError(
          error: err,
          onRetry: () => ref.invalidate(visitsForDayProvider(dayKey)),
        ),
        data: (allVisits) {
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
                  // ── Mobile date navigation (hidden on wide screens) ────────
                  if (MediaQuery.of(context).size.width <= 480)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.wash.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.wash.border),
                          ),
                          child: Row(
                            children: [
                              // Prev arrow
                              IconButton(
                                icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 22),
                                color: context.wash.textSecondary,
                                onPressed: _goToPrevDay,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                              // Tappable date label
                              Expanded(
                                child: GestureDetector(
                                  onTap: _pickDate,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isToday ? 'TODAY' : 'PAST DAY',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                          color: _isToday
                                              ? context.wash.success
                                              : context.wash.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat('EEE, d MMM yyyy')
                                                .format(_selectedDate),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _isToday
                                                  ? context.wash.textPrimary
                                                  : context.wash.accent,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.expand_more_rounded,
                                            size: 14,
                                            color: _isToday
                                                ? context.wash.textMuted
                                                : context.wash.accent,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Next arrow or Back to Today
                              _isToday
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 22),
                                      color: context.wash.textMuted,
                                      onPressed: null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    )
                                  : TextButton(
                                      onPressed: _goToToday,
                                      style: TextButton.styleFrom(
                                        foregroundColor: context.wash.accent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        minimumSize: const Size(0, 36),
                                        textStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      child: const Text('Today'),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),

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
                                    context.wash.accent.withValues(alpha: 0.15),
                                foregroundColor: context.wash.accent,
                                elevation: 0,
                                minimumSize: Size(narrow ? double.infinity : 0, 38),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                side: BorderSide(
                                    color:
                                        context.wash.accent.withValues(alpha: 0.3)),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            );
                            return Container(
                              padding: EdgeInsets.all(narrow ? 20 : 28),
                              decoration: BoxDecoration(
                                color: context.wash.surfaceCard,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: context.wash.border),
                                gradient: LinearGradient(
                                  colors: [
                                    context.wash.surfaceCard,
                                    context.wash.surfaceHigh.withValues(alpha: 0.6),
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
                                      Text(
                                        _isToday
                                            ? 'TODAY\'S REVENUE'
                                            : DateFormat('EEE, d MMM')
                                                .format(_selectedDate)
                                                .toUpperCase(),
                                        style: TextStyle(
                                          color: context.wash.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      if (!narrow && _isToday) closeDayBtn,
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
                                          color: context.wash.accent,
                                          fontSize: revenueFont,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          'across ${allVisits.length} wash${allVisits.length == 1 ? '' : 'es'}',
                                          style: TextStyle(
                                            color: context.wash.textSecondary,
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
                                        color: context.wash.success,
                                      ),
                                      _StatusPill(
                                        label: 'UPI',
                                        amount: '₹$upiRevenue',
                                        color: context.wash.accent,
                                      ),
                                      if (unknownRevenue > 0)
                                        _StatusPill(
                                          label: 'Unknown',
                                          amount: '₹$unknownRevenue',
                                          color: context.wash.textSecondary,
                                        ),
                                      _StatusPill(
                                        label: 'Pending',
                                        amount: '₹$pendingRevenue',
                                        color: pendingRevenue > 0
                                            ? context.wash.danger
                                            : context.wash.textSecondary,
                                      ),
                                    ],
                                  ),
                                  if (narrow && _isToday) ...[
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
                                hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: context.wash.textMuted),
                                prefixIcon: Icon(Icons.search,
                                    size: 18,
                                    color: context.wash.textSecondary),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                fillColor: context.wash.surfaceCard,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: context.wash.border),
                                ),
                              ),
                            );
                            if (narrow) {
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isToday
                                        ? 'Live Log (${visits.length})'
                                        : 'Visit Log (${visits.length})',
                                    style: TextStyle(
                                      color: context.wash.textPrimary,
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
                                  _isToday
                                      ? 'Live Vehicle Log (${visits.length})'
                                      : 'Vehicle Log (${visits.length})',
                                  style: TextStyle(
                                    color: context.wash.textPrimary,
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

                  // Past-day read-only banner
                  if (!_isToday)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.wash.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: context.wash.accent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 16, color: context.wash.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Viewing ${DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)} — read only',
                                  style: TextStyle(
                                    color: context.wash.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _goToToday,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        context.wash.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: context.wash.accent
                                            .withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'Back to Today',
                                    style: TextStyle(
                                      color: context.wash.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

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
                                  color: context.wash.surfaceHigh,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.wash.border),
                                ),
                                child: Icon(Icons.no_crash_rounded,
                                    size: 36, color: context.wash.textMuted),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? (_isToday
                                        ? 'No vehicles logged today yet'
                                        : 'No vehicles were logged on this day')
                                    : 'No matching records for "$_searchQuery"',
                                style: TextStyle(
                                  color: context.wash.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isToday
                                    ? 'Vehicle scans logged by workers will stream here instantly.'
                                    : 'No wash records found for this date.',
                                style: TextStyle(
                                  color: context.wash.textMuted,
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
                          (ctx, i) => _VisitTile(
                            visit: visits[i],
                            readOnly: !_isToday,
                          ),
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
        backgroundColor: context.wash.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Close Day & Send Email?'),
        content: Text(
          'This triggers the automated end-of-day summary email to all configured owner email addresses with today\'s complete breakdown.',
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
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: context.wash.success, size: 20),
                const SizedBox(width: 10),
                const Text('Report queued! Check your inbox shortly.'),
              ],
            ),
            backgroundColor: context.wash.surfaceHigh,
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
        color: context.wash.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.wash.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.wash.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, size: 18, color: context.wash.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count.toString(),
            style: TextStyle(
              color: context.wash.textPrimary,
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
  final bool readOnly;
  const _VisitTile({required this.visit, this.readOnly = false});

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
              backgroundColor: context.wash.danger,
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
            backgroundColor: context.wash.danger,
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
    final packageLabels = ref.watch(packageLabelsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.wash.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/owner/visit/${visit.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.wash.border),
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
                        style: TextStyle(
                          color: context.wash.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: readOnly ? null : () => _togglePaid(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                            _paidBadgeLabel(),
                            style: TextStyle(
                              color: visit.paid
                                  ? context.wash.success
                                  : context.wash.danger,
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
                  Icon(Icons.chevron_right_rounded,
                      color: context.wash.textMuted, size: 20),
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
                          '${VehicleType.label(visit.vehicleType)} · ${resolvePackageLabel(packageLabels, visit.packageId)}',
                          style: TextStyle(
                            color: context.wash.textPrimary,
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
                        style: TextStyle(
                          color: context.wash.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (visit.phone != null &&
                          visit.phone!.isNotEmpty) ...[
                        Text('·',
                            style: TextStyle(
                                color: context.wash.textMuted,
                                fontSize: 12)),
                        Text(
                          visit.phone!,
                          style: TextStyle(
                            color: context.wash.textSecondary,
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

/// Shown when the day's visit stream fails (offline, permission denied, a
/// missing index). Previously these errors were swallowed and the dashboard
/// rendered as if the day had zero washes.
class _DashboardError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DashboardError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.wash.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: context.wash.danger.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.cloud_off_rounded,
                    size: 34, color: context.wash.danger),
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't load today's washes",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.wash.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.wash.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
