// Visit detail — shows plate photo, front photo, all fields, void button.
// Clean desktop and mobile responsive layout.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../providers/package_labels_provider.dart';
import '../../services/providers.dart';
import '../../widgets/payment_method_dialog.dart';

class VisitDetailScreen extends ConsumerStatefulWidget {
  final String visitId;
  const VisitDetailScreen({super.key, required this.visitId});

  @override
  ConsumerState<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends ConsumerState<VisitDetailScreen> {
  // Future stored once in initState so rebuilds (theme change, parent rebuild)
  // don't create a new Future, re-issuing two Firestore reads and flashing
  // the loading spinner every time.
  late final Future<(Visit?, String?)> _dataFuture;

  @override
  void initState() {
    super.initState();
    final svc = ref.read(firestoreServiceProvider);
    _dataFuture = svc.getVisit(widget.visitId).then((visit) async {
      if (visit == null || visit.workerId == null) return (visit, null);
      final names = await svc.fetchOperatorNames({visit.workerId!});
      return (visit, names[visit.workerId!]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(firestoreServiceProvider);
    return Scaffold(
      backgroundColor: context.wash.bg,
      appBar: AppBar(
        title: const Text('Wash Record Details'),
      ),
      body: FutureBuilder<(Visit?, String?)>(
        future: _dataFuture,
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
      // Guard must be set BEFORE the dialog await. If set after, a second tap
      // delivered before the dialog resolves sees _updatingPaid==false and
      // issues a concurrent Firestore write.
      setState(() => _updatingPaid = true);
      final method = await showPaymentMethodDialog(
        context,
        subtitle: 'Plate ${_visit.plate} — ₹${_visit.amount}',
      );
      if (method == null) {
        if (mounted) setState(() => _updatingPaid = false);
        return;
      }

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
              content: const Text('Could not update payment. Try again.'),
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
              content: const Text('Could not update payment. Try again.'),
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
                        visitId: visit.id,
                        urlField: 'platePhotoUrl',
                      ),
                      const SizedBox(height: 12),
                      _PhotoCard(
                        url: visit.frontPhotoUrl,
                        label: 'Vehicle Front & Damage Proof',
                        icon: Icons.camera_front_rounded,
                        visitId: visit.id,
                        urlField: 'frontPhotoUrl',
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
                        visitId: visit.id,
                        urlField: 'platePhotoUrl',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PhotoCard(
                        url: visit.frontPhotoUrl,
                        label: 'Vehicle Front & Damage Proof',
                        icon: Icons.camera_front_rounded,
                        visitId: visit.id,
                        urlField: 'frontPhotoUrl',
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
    final dangerColor = context.wash.danger;
    final surfaceCard = context.wash.surfaceCard;
    final textSecondary = context.wash.textSecondary;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Void this visit?'),
        content: Text(
          'This record will be excluded from revenue calculations and daily reports. High-resolution photos will be retained for dispute verification.',
          style: TextStyle(color: textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Void'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.svc.voidVisit(_visit.id);
        if (mounted) Navigator.of(this.context).pop(); // ignore: use_build_context_synchronously
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar( // ignore: use_build_context_synchronously
            SnackBar(
              content: const Text('Could not void record. Check connection and try again.'),
              backgroundColor: dangerColor,
            ),
          );
        }
      }
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

/// Photo card that auto-refreshes the download URL when the stored token
/// has expired (common for photos uploaded before the storage rules fix).
///
/// On [Image.network] error it calls [FirebaseStorage.ref().getDownloadURL()]
/// using the stored URL's path, writes the fresh URL back to Firestore so
/// future loads are instant, and retries the image.
class _PhotoCard extends StatefulWidget {
  final String? url;
  final String label;
  final IconData icon;
  /// Firestore visit ID — used to persist the refreshed URL so it only
  /// needs to be refreshed once per photo.
  final String? visitId;
  /// Which field to update ('platePhotoUrl' or 'frontPhotoUrl').
  final String? urlField;

  const _PhotoCard({
    this.url,
    required this.label,
    required this.icon,
    this.visitId,
    this.urlField,
  });

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<_PhotoCard> {
  late String? _activeUrl;
  bool _refreshing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.url;
  }

  /// Extracts the Storage object path from a Firebase download URL and
  /// fetches a fresh download URL. Updates Firestore so the next load is
  /// instant (avoids re-refreshing on every open).
  Future<void> _refreshUrl() async {
    if (_refreshing || _activeUrl == null || widget.visitId == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _refreshing = true);
    try {
      // Extract the object path from the stored URL.
      // Firebase download URLs look like:
      //   https://firebasestorage.googleapis.com/v0/b/BUCKET/o/PATH?alt=media&token=TOKEN
      // The PATH segment is URL-encoded, e.g. "plates%2FKA01%2Ffile.jpg".
      final uri = Uri.parse(_activeUrl!);
      // Path segment after /o/ is the encoded storage object path.
      final oIndex = uri.path.indexOf('/o/');
      if (oIndex == -1) {
        setState(() { _refreshing = false; _failed = true; });
        return;
      }
      final encodedPath = uri.path.substring(oIndex + 3);
      final storagePath = Uri.decodeComponent(encodedPath);

      final freshUrl = await FirebaseStorage.instanceFor(
        bucket: 'wash-ledgar.firebasestorage.app',
      ).ref(storagePath).getDownloadURL();

      // Persist the fresh URL to Firestore so this card never needs to
      // refresh again.
      if (widget.visitId != null && widget.urlField != null) {
        await FirebaseFirestore.instance
            .collection('visits')
            .doc(widget.visitId)
            .update({widget.urlField!: freshUrl});
      }

      if (mounted) setState(() { _activeUrl = freshUrl; _refreshing = false; });
    } catch (_) {
      if (mounted) setState(() { _refreshing = false; _failed = true; });
    }
  }

  void _openFullImage(BuildContext context) {
    if (_activeUrl == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      _activeUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54)),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: Colors.white38, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
                Icon(widget.icon, size: 16, color: context.wash.accent),
                const SizedBox(width: 8),
                Text(
                  widget.label,
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
            child: _activeUrl != null
                ? GestureDetector(
                    onTap: () => _openFullImage(context),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          _activeUrl!,
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
                          // On error: try to refresh the download token once.
                          // If already refreshed or no visit ID, show broken icon.
                          errorBuilder: (_, __, ___) {
                            if (!_refreshing && !_failed) {
                              // Schedule refresh after the current frame.
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _refreshUrl());
                            }
                            return Container(
                              height: 220,
                              color: context.wash.surfaceHigh,
                              child: Center(
                                child: _refreshing
                                    ? CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.wash.accent)
                                    : _failed
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.broken_image_rounded,
                                                  color: context.wash.textMuted,
                                                  size: 36),
                                              const SizedBox(height: 8),
                                              Text('Photo unavailable',
                                                  style: TextStyle(
                                                      color: context
                                                          .wash.textMuted,
                                                      fontSize: 12)),
                                            ],
                                          )
                                        : Icon(Icons.broken_image_rounded,
                                            color: context.wash.textMuted,
                                            size: 36),
                              ),
                            );
                          },
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
