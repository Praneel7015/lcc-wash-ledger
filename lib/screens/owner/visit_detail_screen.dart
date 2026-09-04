// Visit detail — shows plate photo, front photo, all fields, void button.
// Clean desktop and mobile responsive layout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../providers/package_labels_provider.dart';
import '../../services/providers.dart';
import '../../widgets/payment_method_dialog.dart';

class VisitDetailScreen extends ConsumerWidget {
  final String visitId;
  const VisitDetailScreen({super.key, required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(firestoreServiceProvider);
    return Scaffold(
      backgroundColor: context.wash.bg,
      appBar: AppBar(
        title: const Text('Wash Record Details'),
      ),
      body: FutureBuilder<(Visit?, String?)>(
        future: svc.getVisit(visitId).then((visit) async {
          if (visit?.workerId == null) return (visit, null);
          final names = await svc.fetchOperatorNames({visit!.workerId!});
          return (visit, names[visit.workerId!]);
        }),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.wash.accent),
            );
          }
          final visit = snap.data?.$1;
          final operatorName = snap.data?.$2;
          if (visit == null) {
            return Center(
              child: Text(
                'Record not found or has been voided.',
                style: TextStyle(color: context.wash.textSecondary),
              ),
            );
          }
          return _VisitDetail(visit: visit, svc: svc, operatorName: operatorName);
        },
      ),
    );
  }
}

class _VisitDetail extends ConsumerStatefulWidget {
  final Visit visit;
  final FirestoreService svc;
  final String? operatorName;

  const _VisitDetail({
    required this.visit,
    required this.svc,
    this.operatorName,
  });

  @override
  ConsumerState<_VisitDetail> createState() => _VisitDetailState();
}

class _VisitDetailState extends ConsumerState<_VisitDetail> {
  late Visit _visit;
  bool _updatingPaid = false;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
  }

  Future<void> _togglePaid() async {
    if (_updatingPaid) return;
    final newPaid = !_visit.paid;

    if (newPaid) {
      final method = await showPaymentMethodDialog(
        context,
        subtitle: 'Plate ${_visit.plate} — ₹${_visit.amount}',
      );
      if (method == null) return;

      setState(() => _updatingPaid = true);
      try {
        await widget.svc.updateVisit(_visit.id, {
          'paid': true,
          'paymentMethod': method,
        });
        if (mounted) {
          setState(() => _visit = _visit.copyWith(
                paid: true,
                paymentMethod: method,
              ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not update payment: $e'),
              backgroundColor: context.wash.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _updatingPaid = false);
      }
      return;
    }

    setState(() => _updatingPaid = true);
    try {
      await widget.svc.updateVisit(_visit.id, {
        'paid': false,
        'paymentMethod': null,
      });
      if (mounted) {
        setState(() => _visit = _visit.copyWith(
              paid: false,
              clearPaymentMethod: true,
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update payment: $e'),
            backgroundColor: context.wash.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPaid = false);
    }
  }

  String _paidBadgeLabel() {
    if (!_visit.paid) return 'UNPAID';
    if (_visit.paymentMethod == PaymentMethod.cash) return 'PAID · CASH';
    if (_visit.paymentMethod == PaymentMethod.upi) return 'PAID · UPI';
    return 'PAID';
  }

  @override
  Widget build(BuildContext context) {
    final visit = _visit;
    final fmt = DateFormat('EEEE, d MMMM yyyy • h:mm a');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header with Plate & Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.wash.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.wash.border),
              ),
              child: Row(
                children: [
                  // Plate Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: WashTheme.plateYellow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: WashTheme.plateBlack, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 2),
                          decoration: BoxDecoration(
                            color: WashTheme.plateBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'IND',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          visit.plate,
                          style: const TextStyle(
                            color: WashTheme.plateBlack,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _updatingPaid ? null : _togglePaid,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: visit.paid
                            ? context.wash.success.withValues(alpha: 0.15)
                            : context.wash.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: visit.paid
                              ? context.wash.success.withValues(alpha: 0.3)
                              : context.wash.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _updatingPaid
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.wash.accent,
                              ),
                            )
                          : Text(
                              _paidBadgeLabel(),
                              style: TextStyle(
                                color: visit.paid
                                    ? context.wash.success
                                    : context.wash.danger,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tap payment status to toggle',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.wash.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),

            // Photos Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                if (isNarrow) {
                  return Column(
                    children: [
                      _PhotoCard(
                        url: visit.platePhotoUrl,
                        label: 'License Plate Capture',
                        icon: Icons.pin_outlined,
                      ),
                      const SizedBox(height: 12),
                      _PhotoCard(
                        url: visit.frontPhotoUrl,
                        label: 'Vehicle Front & Damage Proof',
                        icon: Icons.camera_front_rounded,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _PhotoCard(
                        url: visit.platePhotoUrl,
                        label: 'License Plate Capture',
                        icon: Icons.pin_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PhotoCard(
                        url: visit.frontPhotoUrl,
                        label: 'Vehicle Front & Damage Proof',
                        icon: Icons.camera_front_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Metadata card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.wash.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.wash.border),
              ),
              child: Column(
                children: [
                  _DetailRow('Date & Time', Text(fmt.format(visit.createdAt),
                      style: TextStyle(
                          color: context.wash.textPrimary,
                          fontWeight: FontWeight.w600))),
                  const Divider(height: 24),
                  _DetailRow(
                    'Vehicle Classification',
                    Text(
                      '${VehicleType.emoji(visit.vehicleType)}  ${VehicleType.label(visit.vehicleType)}',
                      style: TextStyle(
                          color: context.wash.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    'Service Package',
                    Text(
                      resolvePackageLabel(
                          ref.watch(packageLabelsProvider), visit.packageId),
                      style: TextStyle(
                          color: context.wash.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    'Service Amount',
                    Text(
                      '₹${visit.amount}',
                      style: TextStyle(
                        color: context.wash.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (visit.paid && visit.paymentMethod != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      'Paid by',
                      Text(
                        PaymentMethod.label(visit.paymentMethod),
                        style: TextStyle(
                          color: context.wash.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (visit.phone != null && visit.phone!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      'Customer Phone',
                      Text(
                        visit.phone!,
                        style: TextStyle(
                          color: context.wash.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_visit.workerId != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      'Operator',
                      Text(
                        widget.operatorName ?? _visit.workerId!,
                        style: TextStyle(
                          color: widget.operatorName != null
                              ? context.wash.textPrimary
                              : context.wash.textMuted,
                          fontSize: widget.operatorName != null ? 14 : 12,
                          fontFamily: widget.operatorName != null
                              ? null
                              : 'JetBrains Mono',
                          fontWeight: widget.operatorName != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Void action button
            OutlinedButton.icon(
              onPressed: () => _confirmVoid(context),
              icon: Icon(Icons.delete_outline_rounded,
                  color: context.wash.danger, size: 18),
              label: Text(
                'Void This Record',
                style: TextStyle(
                    color: context.wash.danger, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.wash.danger),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmVoid(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.wash.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Void this visit?'),
        content: Text(
          'This record will be excluded from revenue calculations and daily reports. High-resolution photos will be retained for dispute verification.',
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
              backgroundColor: context.wash.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Void'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.svc.voidVisit(_visit.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.wash.textSecondary, fontSize: 14)),
          value,
        ],
      );
}

class _PhotoCard extends StatelessWidget {
  final String? url;
  final String label;
  final IconData icon;

  const _PhotoCard({
    this.url,
    required this.label,
    required this.icon,
  });

  void _openFullImage(BuildContext context) {
    if (url == null) return;
    final size = MediaQuery.of(context).size;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: context.wash.surfaceCard,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: size.width > 600 ? 560 : size.width - 32,
          height: (size.height * 0.85).clamp(300.0, 720.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: context.wash.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.network(
                        url!,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.wash.accent,
                                    ),
                                  ),
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: context.wash.textMuted, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.wash.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.wash.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: context.wash.accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: context.wash.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: url != null
                ? GestureDetector(
                    onTap: () => _openFullImage(context),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          url!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      height: 220,
                                      color: context.wash.surfaceHigh,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.wash.accent,
                                        ),
                                      ),
                                    ),
                          errorBuilder: (_, __, ___) => Container(
                            height: 220,
                            color: context.wash.surfaceHigh,
                            child: Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: context.wash.textMuted, size: 36),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'View full',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    height: 220,
                    color: context.wash.surfaceHigh,
                    child: Center(
                      child: Icon(Icons.photo_outlined,
                          color: context.wash.textMuted, size: 36),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
