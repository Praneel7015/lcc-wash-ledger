// Date-range reports screen — week / month / custom filter.
// Shows totals, type breakdown, package breakdown, and CSV export.

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../services/providers.dart';

enum ReportRange { today, week, month, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.month;
  DateTimeRange? _custom;
  List<Visit>? _visits;
  bool _loading = false;

  DateTimeRange get _effectiveRange {
    final now = DateTime.now();
    switch (_range) {
      case ReportRange.today:
        final d = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: d, end: d);
      case ReportRange.week:
        return DateTimeRange(
            start: now.subtract(const Duration(days: 6)), end: now);
      case ReportRange.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: now);
      case ReportRange.custom:
        return _custom ??
            DateTimeRange(
                start: now.subtract(const Duration(days: 30)), end: now);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = _effectiveRange;
      final svc = ref.read(firestoreServiceProvider);
      final visits = await svc.visitsForRange(r.start, r.end);
      if (mounted) setState(() => _visits = visits);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _custom ??
          DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now()),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: WashTheme.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _custom = picked;
        _range = ReportRange.custom;
      });
      _load();
    }
  }

  void _exportCsv() {
    if (_visits == null || _visits!.isEmpty) return;
    final rows = [
      ['Date', 'Time', 'Plate', 'Vehicle', 'Package', 'Amount', 'Paid', 'Phone'],
      ..._visits!.map((v) => [
            DateFormat('yyyy-MM-dd').format(v.createdAt),
            DateFormat('HH:mm').format(v.createdAt),
            v.plate,
            VehicleType.label(v.vehicleType),
            WashPackage.label(v.packageId),
            v.amount,
            v.paid ? 'Yes' : 'No',
            v.phone ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = Uri.dataFromBytes(bytes,
        mimeType: 'text/csv',
        parameters: {'charset': 'utf-8'});
    if (kIsWeb) {
      launchUrl(blob);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = _visits ?? [];
    final totalRevenue = visits.fold<int>(0, (s, v) => s + v.amount);
    final paidRevenue =
        visits.where((v) => v.paid).fold<int>(0, (s, v) => s + v.amount);
    final pendingRevenue = totalRevenue - paidRevenue;
    final countByType = <String, int>{};
    final revenueByType = <String, int>{};
    final countByPkg = <String, int>{};
    for (final v in visits) {
      countByType[v.vehicleType] = (countByType[v.vehicleType] ?? 0) + 1;
      revenueByType[v.vehicleType] =
          (revenueByType[v.vehicleType] ?? 0) + v.amount;
      countByPkg[v.packageId] = (countByPkg[v.packageId] ?? 0) + 1;
    }
    final r = _effectiveRange;
    final rangeLabel =
        '${DateFormat('d MMM yyyy').format(r.start)} – ${DateFormat('d MMM yyyy').format(r.end)}';

    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        title: const Text('Analytics & Financial Reports'),
        actions: [
          if (visits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Export CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WashTheme.surfaceHigh,
                  foregroundColor: WashTheme.textPrimary,
                  minimumSize: const Size(0, 36),
                  side: const BorderSide(color: WashTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: _exportCsv,
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Selector Tabs
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: WashTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WashTheme.border),
                ),
                child: Row(
                  children: [
                    _RangePill(
                      label: 'Today',
                      selected: _range == ReportRange.today,
                      onTap: () {
                        setState(() => _range = ReportRange.today);
                        _load();
                      },
                    ),
                    _RangePill(
                      label: 'Last 7 Days',
                      selected: _range == ReportRange.week,
                      onTap: () {
                        setState(() => _range = ReportRange.week);
                        _load();
                      },
                    ),
                    _RangePill(
                      label: 'This Month',
                      selected: _range == ReportRange.month,
                      onTap: () {
                        setState(() => _range = ReportRange.month);
                        _load();
                      },
                    ),
                    _RangePill(
                      label: 'Custom Range',
                      selected: _range == ReportRange.custom,
                      onTap: _pickCustom,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded,
                        size: 14, color: WashTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        color: WashTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: WashTheme.accent),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Revenue Overview Card
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: WashTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: WashTheme.border),
                              gradient: LinearGradient(
                                colors: [
                                  WashTheme.surfaceCard,
                                  WashTheme.surfaceHigh.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'TOTAL REVENUE',
                                          style: TextStyle(
                                            color: WashTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '₹$totalRevenue',
                                          style: const TextStyle(
                                            color: WashTheme.accent,
                                            fontSize: 48,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: WashTheme.surfaceHigh,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: WashTheme.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${visits.length} Washes',
                                            style: const TextStyle(
                                              color: WashTheme.textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Avg ₹${visits.isNotEmpty ? (totalRevenue / visits.length).round() : 0} / wash',
                                            style: const TextStyle(
                                              color: WashTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _ReportTag(
                                      label: 'Collected Cash',
                                      value: '₹$paidRevenue',
                                      color: WashTheme.success,
                                    ),
                                    const SizedBox(width: 12),
                                    _ReportTag(
                                      label: 'Pending Balance',
                                      value: '₹$pendingRevenue',
                                      color: pendingRevenue > 0
                                          ? WashTheme.danger
                                          : WashTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // By vehicle type breakdown
                          const _SectionTitle(
                            title: 'Volume & Revenue by Vehicle Type',
                            icon: Icons.directions_car_rounded,
                          ),
                          const SizedBox(height: 10),
                          ...VehicleType.all.map((type) {
                            final count = countByType[type] ?? 0;
                            final rev = revenueByType[type] ?? 0;
                            return _BreakdownCard(
                              emoji: VehicleType.emoji(type),
                              label: VehicleType.label(type),
                              count: count,
                              revenue: rev,
                              total: visits.isNotEmpty ? visits.length : 1,
                            );
                          }),
                          const SizedBox(height: 24),

                          // By package breakdown
                          const _SectionTitle(
                            title: 'Service Package Distribution',
                            icon: Icons.cleaning_services_rounded,
                          ),
                          const SizedBox(height: 10),
                          ...WashPackage.all.map((pkg) {
                            final count = countByPkg[pkg] ?? 0;
                            return _BreakdownCard(
                              emoji: '✨',
                              label: WashPackage.label(pkg),
                              count: count,
                              total: visits.isNotEmpty ? visits.length : 1,
                            );
                          }),
                          const SizedBox(height: 40),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? WashTheme.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? WashTheme.accent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? WashTheme.accent : WashTheme.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReportTag({
    required this.label,
    required this.value,
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
          Text('$label: ',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: WashTheme.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: WashTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final int total;
  final int? revenue;

  const _BreakdownCard({
    required this.emoji,
    required this.label,
    required this.count,
    required this.total,
    this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;
    final fraction = total > 0 ? count / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WashTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WashTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: WashTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count ($percentage%)',
                style: const TextStyle(
                  color: WashTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (revenue != null) ...[
                const SizedBox(width: 16),
                Text(
                  '₹$revenue',
                  style: const TextStyle(
                    color: WashTheme.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: WashTheme.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(WashTheme.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
