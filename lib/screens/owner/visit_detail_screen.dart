// Visit detail — shows plate photo, front photo, all fields, void button.
// Clean desktop and mobile responsive layout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../services/providers.dart';

class VisitDetailScreen extends ConsumerWidget {
  final String visitId;
  const VisitDetailScreen({super.key, required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(firestoreServiceProvider);
    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        title: const Text('Wash Record Details'),
      ),
      body: FutureBuilder<Visit?>(
        future: svc.getVisit(visitId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: WashTheme.accent),
            );
          }
          final visit = snap.data;
          if (visit == null) {
            return const Center(
              child: Text(
                'Record not found or has been voided.',
                style: TextStyle(color: WashTheme.textSecondary),
              ),
            );
          }
          return _VisitDetail(visit: visit, svc: svc);
        },
      ),
    );
  }
}

class _VisitDetail extends StatelessWidget {
  final Visit visit;
  final FirestoreService svc;
  const _VisitDetail({required this.visit, required this.svc});

  @override
  Widget build(BuildContext context) {
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
                color: WashTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WashTheme.border),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: visit.paid
                          ? WashTheme.success.withValues(alpha: 0.15)
                          : WashTheme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: visit.paid
                            ? WashTheme.success.withValues(alpha: 0.3)
                            : WashTheme.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      visit.paid ? 'PAID' : 'UNPAID',
                      style: TextStyle(
                        color: visit.paid
                            ? WashTheme.success
                            : WashTheme.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
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
                color: WashTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WashTheme.border),
              ),
              child: Column(
                children: [
                  _DetailRow('Date & Time', Text(fmt.format(visit.createdAt),
                      style: const TextStyle(
                          color: WashTheme.textPrimary,
                          fontWeight: FontWeight.w600))),
                  const Divider(height: 24),
                  _DetailRow(
                    'Vehicle Classification',
                    Text(
                      '${VehicleType.emoji(visit.vehicleType)}  ${VehicleType.label(visit.vehicleType)}',
                      style: const TextStyle(
                          color: WashTheme.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    'Service Package',
                    Text(
                      WashPackage.label(visit.packageId),
                      style: const TextStyle(
                          color: WashTheme.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    'Service Amount',
                    Text(
                      '₹${visit.amount}',
                      style: const TextStyle(
                        color: WashTheme.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (visit.phone != null && visit.phone!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      'Customer Phone',
                      Text(
                        visit.phone!,
                        style: const TextStyle(
                          color: WashTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (visit.workerId != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      'Operator ID',
                      Text(
                        visit.workerId!,
                        style: const TextStyle(
                          color: WashTheme.textMuted,
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
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
              icon: const Icon(Icons.delete_outline_rounded,
                  color: WashTheme.danger, size: 18),
              label: const Text(
                'Void This Record',
                style: TextStyle(
                    color: WashTheme.danger, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WashTheme.danger),
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
        backgroundColor: WashTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Void this visit?'),
        content: const Text(
          'This record will be excluded from revenue calculations and daily reports. High-resolution photos will be retained for dispute verification.',
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
              backgroundColor: WashTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Void'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await svc.voidVisit(visit.id);
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
              style: const TextStyle(
                  color: WashTheme.textSecondary, fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WashTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WashTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: WashTheme.accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: WashTheme.textSecondary,
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
                ? Image.network(
                    url!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 220,
                            color: WashTheme.surfaceHigh,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WashTheme.accent,
                              ),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: WashTheme.surfaceHigh,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: WashTheme.textMuted, size: 36),
                      ),
                    ),
                  )
                : Container(
                    height: 220,
                    color: WashTheme.surfaceHigh,
                    child: const Center(
                      child: Icon(Icons.photo_outlined,
                          color: WashTheme.textMuted, size: 36),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
