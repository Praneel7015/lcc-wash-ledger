// Screen 5: phone number + paid toggle + save.
// Phone pre-fills if returning customer. Saves visit to Firestore + uploads photos.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/visit.dart';
import '../../models/wash_draft.dart';
import '../../providers/wash_session_provider.dart';
import '../../services/providers.dart';
import '../../widgets/worker_app_bar.dart';

class PhonePaidScreen extends ConsumerStatefulWidget {
  final WashDraft draft;
  const PhonePaidScreen({super.key, required this.draft});

  @override
  ConsumerState<PhonePaidScreen> createState() => _PhonePaidScreenState();
}

class _PhonePaidScreenState extends ConsumerState<PhonePaidScreen> {
  late TextEditingController _phoneCtrl;
  bool _paid = true;
  String? _paymentMethod;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.draft.phone ?? '');
    _paid = widget.draft.paid;
    _paymentMethod = widget.draft.paymentMethod;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final storage = ref.read(storageServiceProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Upload both photos in parallel
      final results = await Future.wait<String>([
        storage.uploadPhoto(
          bytes: Uint8List.fromList(widget.draft.plateImageBytes),
          folder: 'plates',
          plate: widget.draft.plate,
        ),
        storage.uploadPhoto(
          bytes: Uint8List.fromList(widget.draft.frontImageBytes),
          folder: 'fronts',
          plate: widget.draft.plate,
        ),
      ]);

      final visit = Visit(
        id: '',
        plate: widget.draft.plate,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        vehicleType: widget.draft.vehicleType,
        packageId: widget.draft.packageId,
        amount: widget.draft.amount,
        paid: _paid,
        paymentMethod: _paid ? _paymentMethod : null,
        workerId: uid,
        createdAt: DateTime.now(),
        platePhotoUrl: results[0],
        frontPhotoUrl: results[1],
      );

      await svc.saveVisit(visit);
      await svc.upsertCustomer(widget.draft.plate, visit.phone);

      if (mounted) {
        _showSuccessAndReset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: WashTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccessAndReset() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: WashTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: WashTheme.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Wash saved',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.draft.plate}  ·  ₹${widget.draft.amount}',
              style: const TextStyle(color: WashTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(washSessionProvider.notifier).state++;
                Navigator.of(context).pop();
                context.go('/worker/capture-plate');
              },
              child: const Text('New wash'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WorkerAppBar(
          title: 'Save wash', subtitle: widget.draft.plate),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WashTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WashTheme.border),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Plate',
                      value: widget.draft.plate,
                      isPlate: true,
                    ),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Type',
                      value: VehicleType.label(widget.draft.vehicleType),
                    ),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Package',
                      value: WashPackage.label(widget.draft.packageId),
                    ),
                    const Divider(height: 20),
                    _SummaryRow(
                      label: 'Amount',
                      value: '₹${widget.draft.amount}',
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Phone
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: WashTheme.textPrimary, fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Customer phone',
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: WashTheme.textSecondary),
                  hintText: '9876543210',
                ),
              ),
              const SizedBox(height: 20),

              // Payment status — two explicit options
              Text(
                'Payment status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      label: 'Paid',
                      icon: Icons.check_circle_rounded,
                      selected: _paid,
                      color: WashTheme.success,
                      onTap: () => setState(() {
                        _paid = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      label: 'Not paid',
                      icon: Icons.schedule_rounded,
                      selected: !_paid,
                      color: WashTheme.danger,
                      onTap: () => setState(() {
                        _paid = false;
                        _paymentMethod = null;
                      }),
                    ),
                  ),
                ],
              ),
              if (_paid) ...[
                const SizedBox(height: 20),
                Text(
                  'Paid by',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentOption(
                        label: 'Cash',
                        icon: Icons.payments_outlined,
                        selected: _paymentMethod == PaymentMethod.cash,
                        color: WashTheme.accent,
                        onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.cash),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PaymentOption(
                        label: 'UPI',
                        icon: Icons.qr_code_2_rounded,
                        selected: _paymentMethod == PaymentMethod.upi,
                        color: WashTheme.accent,
                        onTap: () =>
                            setState(() => _paymentMethod = PaymentMethod.upi),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: (_saving || (_paid && _paymentMethod == null))
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: WashTheme.bg),
                      )
                    : const Text('Save wash', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : WashTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : WashTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : WashTheme.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : WashTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlate;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isPlate = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: WashTheme.textSecondary, fontSize: 15)),
        if (isPlate)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: WashTheme.plateYellow,
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: WashTheme.plateBlack, width: 1.5),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: WashTheme.plateBlack,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              color: highlight ? WashTheme.accent : WashTheme.textPrimary,
              fontSize: highlight ? 22 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
