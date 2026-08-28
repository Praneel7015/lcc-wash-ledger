// Date-range reports screen — week / month / custom filter.
// Shows totals, type breakdown, package breakdown, and CSV export.

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

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
        '${DateFormat('d MMM').format(r.start)} – ${DateFormat('d MMM yyyy').format(r.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (visits.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
        ],
      ),
      body: Column(
        children: [
          // Range selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _RangeChip(
                    label: 'Today',
                    selected: _range == ReportRange.today,
                    onTap: () {
                      setState(() => _range = ReportRange.today);
                      _load();
                    }),
                const SizedBox(width: 8),
                _RangeChip(
                    label: '7 days',
                    selected: _range == ReportRange.week,
                    onTap: () {
                      setState(() => _range = ReportRange.week);
                      _load();
                    }),
                const SizedBox(width: 8),
                _RangeChip(
                    label: 'This month',
                    selected: _range == ReportRange.month,
                    onTap: () {
                      setState(() => _range = ReportRange.month);
                      _load();
                    }),
                const SizedBox(width: 8),
                _RangeChip(
                    label: 'Custom',
                    selected: _range == ReportRange.custom,
                    onTap: _pickCustom),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(rangeLabel,
                style: const TextStyle(
                    color: WashTheme.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: WashTheme.accent))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Big total
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: WashTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WashTheme.border),
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
                                    const Text('Total revenue',
                                        style: TextStyle(
                                            color: WashTheme.textSecondary,
                                            fontSize: 14)),
                                    Text(
                                      '₹$totalRevenue',
                                      style: const TextStyle(
                                        color: WashTheme.accent,
                                        fontSize: 48,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${visits.length} vehicles',
                                        style: const TextStyle(
                                            color: WashTheme.textPrimary,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        '₹$paidRevenue collected',
                                        style: const TextStyle(
                                            color: WashTheme.success,
                                            fontSize: 13)),
                                    Text(
                                        '₹${totalRevenue - paidRevenue} pending',
                                        style: const TextStyle(
                                            color: WashTheme.danger,
                                            fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // By vehicle type
                      _SectionHeader('By vehicle type'),
                      ...VehicleType.all.map((type) {
                        final count = countByType[type] ?? 0;
                        final rev = revenueByType[type] ?? 0;
                        return _BreakdownTile(
                          label:
                              '${VehicleType.emoji(type)}  ${VehicleType.label(type)}',
                          count: count,
                          revenue: rev,
                          total: visits.isNotEmpty ? visits.length : 1,
                        );
                      }),
                      const SizedBox(height: 16),

                      // By package
                      _SectionHeader('By package'),
                      ...WashPackage.all.map((pkg) {
                        final count = countByPkg[pkg] ?? 0;
                        return _BreakdownTile(
                          label: WashPackage.label(pkg),
                          count: count,
                          total: visits.isNotEmpty ? visits.length : 1,
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? WashTheme.accent.withOpacity(0.15)
                : WashTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? WashTheme.accent : WashTheme.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? WashTheme.accent : WashTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
              color: WashTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
      );
}

class _BreakdownTile extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final int? revenue;
  const _BreakdownTile(
      {required this.label,
      required this.count,
      required this.total,
      this.revenue});

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WashTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WashTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: WashTheme.textPrimary, fontSize: 14)),
              ),
              Text('$count vehicles',
                  style: const TextStyle(
                      color: WashTheme.textSecondary, fontSize: 13)),
              if (revenue != null) ...[
                const SizedBox(width: 12),
                Text('₹$revenue',
                    style: const TextStyle(
                        color: WashTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: WashTheme.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(WashTheme.accent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
