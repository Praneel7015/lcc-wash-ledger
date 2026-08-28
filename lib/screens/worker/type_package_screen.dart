// Screen 4: vehicle type (3 big buttons) + package picker.
// Amount auto-fills from the rate table.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/wash_draft.dart';
import '../../providers/rates_provider.dart';
import '../../widgets/worker_app_bar.dart';

class TypePackageScreen extends ConsumerStatefulWidget {
  final String plate;
  final List<int> plateImageBytes;
  final List<int> frontImageBytes;

  const TypePackageScreen({
    super.key,
    required this.plate,
    required this.plateImageBytes,
    required this.frontImageBytes,
  });

  @override
  ConsumerState<TypePackageScreen> createState() => _TypePackageScreenState();
}

class _TypePackageScreenState extends ConsumerState<TypePackageScreen> {
  String? _vehicleType;
  String? _packageId;

  int get _amount {
    if (_vehicleType == null || _packageId == null) return 0;
    return ref.watch(selectedAmountProvider(
      (vehicleType: _vehicleType!, packageId: _packageId!),
    ));
  }

  void _proceed() {
    if (_vehicleType == null || _packageId == null) return;
    final draft = WashDraft(
      plate: widget.plate,
      plateImageBytes: widget.plateImageBytes,
      frontImageBytes: widget.frontImageBytes,
      vehicleType: _vehicleType!,
      packageId: _packageId!,
      amount: _amount,
    );
    context.push('/worker/phone-paid', extra: {'draft': draft});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WorkerAppBar(
          title: 'Vehicle type & wash', subtitle: widget.plate),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vehicle front preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uint8List.fromList(widget.frontImageBytes),
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 28),

              Text('Vehicle type',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: VehicleType.all.map((type) {
                  final selected = _vehicleType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _VehicleTypeButton(
                        label: VehicleType.label(type),
                        emoji: VehicleType.emoji(type),
                        selected: selected,
                        onTap: () => setState(() => _vehicleType = type),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),
              Text('Wash package',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),

              ...WashPackage.all.map((pkg) {
                final selected = _packageId == pkg;
                final amount = _vehicleType != null
                    ? ref.watch(selectedAmountProvider(
                        (vehicleType: _vehicleType!, packageId: pkg),
                      ))
                    : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PackageButton(
                    label: WashPackage.label(pkg),
                    amount: amount,
                    selected: selected,
                    onTap: () => setState(() => _packageId = pkg),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Amount display
              if (_vehicleType != null && _packageId != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: WashTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: WashTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount',
                          style: TextStyle(
                              color: WashTheme.textSecondary, fontSize: 16)),
                      Text(
                        '₹$_amount',
                        style: const TextStyle(
                          color: WashTheme.accent,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    (_vehicleType != null && _packageId != null) ? _proceed : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleTypeButton extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleTypeButton({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? WashTheme.accent.withValues(alpha: 0.12) : WashTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? WashTheme.accent : WashTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? WashTheme.accent : WashTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageButton extends StatelessWidget {
  final String label;
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  const _PackageButton({
    required this.label,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? WashTheme.accent.withValues(alpha: 0.1) : WashTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? WashTheme.accent : WashTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? WashTheme.accent : WashTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? WashTheme.accent : WashTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (amount > 0)
              Text(
                '₹$amount',
                style: TextStyle(
                  color: selected ? WashTheme.accent : WashTheme.textSecondary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
