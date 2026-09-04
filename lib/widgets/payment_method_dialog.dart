// Dialog to pick Cash or UPI when marking a wash as paid.

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Returns `'cash'`, `'upi'`, or `null` if cancelled.
Future<String?> showPaymentMethodDialog(
  BuildContext context, {
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.wash.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Paid by'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle,
              style: TextStyle(
                color: context.wash.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _MethodOption(
                  label: 'Cash',
                  icon: Icons.payments_outlined,
                  onTap: () => Navigator.pop(ctx, PaymentMethod.cash),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodOption(
                  label: 'UPI',
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => Navigator.pop(ctx, PaymentMethod.upi),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.wash.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _MethodOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MethodOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: context.wash.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.wash.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.wash.accent, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.wash.textPrimary,
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
