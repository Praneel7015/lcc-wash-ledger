// Visit detail — shows plate photo, front photo, all fields, void button.

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
      appBar: AppBar(title: const Text('Visit detail')),
      body: FutureBuilder<Visit?>(
        future: svc.getVisit(visitId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: WashTheme.accent));
          }
          final visit = snap.data;
          if (visit == null) {
            return const Center(child: Text('Visit not found'));
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
    final fmt = DateFormat('EEE d MMM yyyy, h:mm a');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Photos row
        Row(
          children: [
            Expanded(
              child: _PhotoCard(
                  url: visit.platePhotoUrl, label: 'Plate photo'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoCard(
                  url: visit.frontPhotoUrl, label: 'Vehicle photo'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Details card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WashTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WashTheme.border),
          ),
          child: Column(
            children: [
              _DetailRow('Plate', _PlateBadge(plate: visit.plate)),
              const Divider(height: 20),
              _DetailRow('Date & time', Text(fmt.format(visit.createdAt),
                  style: const TextStyle(color: WashTheme.textPrimary))),
              const Divider(height: 20),
              _DetailRow(
                  'Vehicle',
                  Text(
                      '${VehicleType.emoji(visit.vehicleType)}  ${VehicleType.label(visit.vehicleType)}',
                      style:
                          const TextStyle(color: WashTheme.textPrimary))),
              const Divider(height: 20),
              _DetailRow(
                  'Package',
                  Text(WashPackage.label(visit.packageId),
                      style:
                          const TextStyle(color: WashTheme.textPrimary))),
              const Divider(height: 20),
              _DetailRow(
                  'Amount',
                  Text('₹${visit.amount}',
                      style: const TextStyle(
                          color: WashTheme.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w700))),
              const Divider(height: 20),
              _DetailRow(
                  'Payment',
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: visit.paid
                          ? WashTheme.success.withValues(alpha: 0.15)
                          : WashTheme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      visit.paid ? 'Paid' : 'Unpaid',
                      style: TextStyle(
                        color: visit.paid
                            ? WashTheme.success
                            : WashTheme.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )),
              if (visit.phone != null) ...[
                const Divider(height: 20),
                _DetailRow(
                    'Phone',
                    Text(visit.phone!,
                        style: const TextStyle(
                            color: WashTheme.textPrimary))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Void button
        OutlinedButton.icon(
          onPressed: () => _confirmVoid(context),
          icon: const Icon(Icons.delete_outline, color: WashTheme.danger),
          label: const Text('Void this record',
              style: TextStyle(color: WashTheme.danger)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WashTheme.danger),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _confirmVoid(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WashTheme.surface,
        title: const Text('Void record?'),
        content: const Text(
          'The record will be hidden from all reports. Photos are kept.',
          style: TextStyle(color: WashTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: WashTheme.danger),
            child: const Text('Void'),
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

class _PlateBadge extends StatelessWidget {
  final String plate;
  const _PlateBadge({required this.plate});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: WashTheme.plateYellow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: WashTheme.plateBlack, width: 1.5),
        ),
        child: Text(
          plate,
          style: const TextStyle(
            color: WashTheme.plateBlack,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
      );
}

class _PhotoCard extends StatelessWidget {
  final String? url;
  final String label;
  const _PhotoCard({this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: WashTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: url != null
              ? Image.network(
                  url!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          height: 140,
                          color: WashTheme.surfaceHigh,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: WashTheme.accent)),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: WashTheme.surfaceHigh,
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            color: WashTheme.textSecondary)),
                  ),
                )
              : Container(
                  height: 140,
                  color: WashTheme.surfaceHigh,
                  child: const Center(
                      child: Icon(Icons.photo_outlined,
                          color: WashTheme.textSecondary)),
                ),
        ),
      ],
    );
  }
}
