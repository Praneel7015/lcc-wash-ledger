// Screen 2: show OCR result in a giant India-plate-shaped field.
// Worker corrects if wrong. Shows returning-customer banner.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';
import '../../services/providers.dart';
import '../../widgets/worker_app_bar.dart';

class ConfirmPlateScreen extends ConsumerStatefulWidget {
  final List<int> imageBytes;
  final String ocrText;

  const ConfirmPlateScreen({
    super.key,
    required this.imageBytes,
    required this.ocrText,
  });

  @override
  ConsumerState<ConfirmPlateScreen> createState() => _ConfirmPlateScreenState();
}

class _ConfirmPlateScreenState extends ConsumerState<ConfirmPlateScreen> {
  late TextEditingController _ctrl;
  Customer? _customer;
  bool _loadingCustomer = false;
  bool _alreadyToday = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.ocrText);
    _lookupCustomer(widget.ocrText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCustomer(String raw) async {
    final plate = normalisePlate(raw);
    if (plate.isEmpty) return;
    setState(() => _loadingCustomer = true);
    final svc = ref.read(firestoreServiceProvider);
    final customer = await svc.getCustomer(plate);
    final alreadyToday = await svc.wasLoggedToday(plate);
    if (mounted) {
      setState(() {
        _customer = customer;
        _alreadyToday = alreadyToday;
        _loadingCustomer = false;
      });
    }
  }

  void _proceed() {
    final plate = normalisePlate(_ctrl.text.trim());
    if (plate.isEmpty) return;
    context.push('/worker/capture-front', extra: {
      'plate': plate,
      'plateImageBytes': widget.imageBytes,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WorkerAppBar(title: 'Confirm plate'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail of the plate photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uint8List.fromList(widget.imageBytes),
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),

              Text('Plate number',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),

              // India-plate-shaped text field (yellow background, bold black)
              Container(
                decoration: BoxDecoration(
                  color: WashTheme.plateYellow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: WashTheme.plateBlack, width: 3),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: WashTheme.plateBlack,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    hintText: 'KA01AB1234',
                    hintStyle: TextStyle(
                      color: Color(0x88000000),
                      fontSize: 28,
                      letterSpacing: 4,
                    ),
                  ),
                  onChanged: (v) => _lookupCustomer(v),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Plate looks wrong? Edit above.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 24),

              // Returning customer banner
              if (_loadingCustomer)
                const Center(
                    child: CircularProgressIndicator(color: WashTheme.accent))
              else if (_customer != null) ...[
                _CustomerBanner(customer: _customer!),
              ],

              // Already-today warning
              if (_alreadyToday) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WashTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: WashTheme.warning.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: WashTheme.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already logged today — double tap?',
                          style: TextStyle(
                              color: WashTheme.warning, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _proceed,
                child: const Text('Plate is correct — next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerBanner extends StatelessWidget {
  final Customer customer;
  const _CustomerBanner({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WashTheme.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WashTheme.success.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WashTheme.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.repeat, color: WashTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning customer · ${customer.visitCount} visits',
                  style: const TextStyle(
                    color: WashTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (customer.phone != null)
                  Text(
                    customer.phone!,
                    style: const TextStyle(
                        color: WashTheme.textSecondary, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
