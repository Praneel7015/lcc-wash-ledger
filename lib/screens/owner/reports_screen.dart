// Date-range reports screen — week / month / custom filter.
// Shows totals, type breakdown, package breakdown, CSV and PDF export.

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../providers/packages_provider.dart';
import '../../services/providers.dart';
import '../../services/report_pdf_service.dart';

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

  Future<Map<String, String>> _loadPackageLabels() async {
    final packages = await ref.read(packagesProvider.future);
    return {
      for (final p in packages) p['id'] as String: p['label'] as String,
    };
  }

  String _packageLabel(String id, Map<String, String> labels) =>
      labels[id] ?? WashPackage.label(id);

  /// Live packages from Firestore, plus any legacy IDs still present in visits.
  List<String> _packageIdsForBreakdown(
    List<Map<String, dynamic>>? packages,
    Map<String, int> countByPkg,
  ) {
    final ids = <String>[];
    final seen = <String>{};
    if (packages != null) {
      for (final p in packages) {
        final id = p['id'] as String;
        ids.add(id);
        seen.add(id);
      }
    }
    for (final id in countByPkg.keys) {
      if (!seen.contains(id)) {
        ids.add(id);
        seen.add(id);
      }
    }
    return ids;
  }

  void _exportCsv(Map<String, String> labels) {
    if (_visits == null || _visits!.isEmpty) return;
    final rows = [
      [
        'Date',
        'Time',
        'Plate',
        'Vehicle',
        'Package',
        'Amount',
        'Paid',
        'Paid by',
        'Phone',
      ],
      ..._visits!.map((v) => [
            DateFormat('yyyy-MM-dd').format(v.createdAt),
            DateFormat('HH:mm').format(v.createdAt),
            v.plate,
            VehicleType.label(v.vehicleType),
            _packageLabel(v.packageId, labels),
            v.amount,
            v.paid ? 'Yes' : 'No',
            PaymentMethod.reportLabel(paid: v.paid, method: v.paymentMethod),
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

  Future<void> _exportPdf(Map<String, String> labels) async {
    final visits = _visits ?? [];
    if (visits.isEmpty) return;

    final input = ReportPdfInput(
      range: _effectiveRange,
      visits: visits,
      packageLabels: labels,
      breakdown: computeRevenueBreakdown(visits),
    );

    final bytes = await ReportPdfService.build(input);
    final filename = ReportPdfService.filenameFor(input);

    if (kIsWeb) {
      final blob = Uri.dataFromBytes(
        bytes,
        mimeType: 'application/pdf',
        parameters: {'filename': filename},
      );
      await launchUrl(blob);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = _visits ?? [];
    final packagesAsync = ref.watch(packagesProvider);
    final packages = packagesAsync.valueOrNull;
    final packageLabels = packages == null
        ? <String, String>{}
        : {for (final p in packages) p['id'] as String: p['label'] as String};
    final breakdown = computeRevenueBreakdown(visits);
    final totalRevenue = breakdown.total;
    final cashRevenue = breakdown.cash;
    final upiRevenue = breakdown.upi;
    final unknownRevenue = breakdown.unknown;
    final pendingRevenue = breakdown.pending;
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
    final packageIds = _packageIdsForBreakdown(packages, countByPkg);

    Future<void> exportWithLabels(String type) async {
      final labels = packageLabels.isNotEmpty
          ? packageLabels
          : await _loadPackageLabels();
      if (type == 'csv') {
        _exportCsv(labels);
      } else {
        await _exportPdf(labels);
      }
    }

    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        actions: [
          if (visits.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export',
              color: WashTheme.surfaceCard,
              onSelected: (val) => exportWithLabels(val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(children: [
                    Icon(Icons.table_chart_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Export CSV'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Export PDF'),
                  ]),
                ),
              ],
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
                            padding: const EdgeInsets.all(20),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'TOTAL REVENUE',
                                            style: TextStyle(
                                              color: WashTheme.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '₹$totalRevenue',
                                              style: const TextStyle(
                                                color: WashTheme.accent,
                                                fontSize: 44,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: WashTheme.surfaceHigh,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: WashTheme.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${visits.length} Washes',
                                            style: const TextStyle(
                                              color: WashTheme.textPrimary,
                                              fontSize: 16,
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
                                const SizedBox(height: 14),
                                // Tags wrap so they never overflow on narrow screens
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _ReportTag(
                                      label: 'Cash collected',
                                      value: '₹$cashRevenue',
                                      color: WashTheme.success,
                                    ),
                                    _ReportTag(
                                      label: 'UPI collected',
                                      value: '₹$upiRevenue',
                                      color: WashTheme.accent,
                                    ),
                                    if (unknownRevenue > 0)
                                      _ReportTag(
                                        label: 'Unknown method',
                                        value: '₹$unknownRevenue',
                                        color: WashTheme.textSecondary,
                                      ),
                                    _ReportTag(
                                      label: 'Pending',
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
                          ...packageIds.map((pkg) {
                            final count = countByPkg[pkg] ?? 0;
                            return _BreakdownCard(
                              emoji: '✨',
                              label: _packageLabel(pkg, packageLabels),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count ($percentage%)',
                    style: const TextStyle(
                      color: WashTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (revenue != null)
                    Text(
                      '₹$revenue',
                      style: const TextStyle(
                        color: WashTheme.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: WashTheme.surfaceHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(WashTheme.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
