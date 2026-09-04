// Screen 2: show OCR result in a giant India-plate-shaped field.
// Worker corrects if wrong. Shows returning-customer banner.

import 'dart:async';
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

  // The lookup used to fire on every keystroke — two Firestore reads per
  // character typed, with no ordering guarantee between responses. Debounce
  // the calls and stamp each one so a slow earlier reply can't overwrite a
  // newer result.
  Timer? _lookupDebounce;
  int _lookupSeq = 0;
  String? _lastLookedUpPlate;

  static const _lookupDelay = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    final formatted = widget.ocrText.isEmpty
        ? ''
        : formatIndianPlate(widget.ocrText);
    _ctrl = TextEditingController(text: formatted);
    _lookupCustomer(widget.ocrText);
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onPlateChanged(String raw) {
    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(_lookupDelay, () => _lookupCustomer(raw));
  }

  Future<void> _lookupCustomer(String raw) async {
    final plate = normalisePlate(raw);
    if (plate.isEmpty) {
      if (mounted && (_customer != null || _alreadyToday)) {
        setState(() {
          _customer = null;
          _alreadyToday = false;
        });
      }
      return;
    }
    // Nothing changed since the last completed lookup.
    if (plate == _lastLookedUpPlate) return;

    final seq = ++_lookupSeq;
    setState(() => _loadingCustomer = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final results = await Future.wait([
        svc.getCustomer(plate),
        svc.wasLoggedToday(plate),
      ]);
      if (!mounted || seq != _lookupSeq) return; // a newer lookup won
      setState(() {
        _customer = results[0] as Customer?;
        _alreadyToday = results[1] as bool;
        _loadingCustomer = false;
        _lastLookedUpPlate = plate;
      });
    } catch (_) {
      if (mounted && seq == _lookupSeq) {
        setState(() => _loadingCustomer = false);
      }
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
                  height: 120,
                  width: double.infinity,
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: WashTheme.plateBlack,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    hintText: 'KA 01 AB 1234',
                    hintStyle: TextStyle(
                      color: Color(0x88000000),
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
                  onChanged: _onPlateChanged,
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
                Center(
                    child: CircularProgressIndicator(color: context.wash.accent))
              else if (_customer != null) ...[
                _CustomerBanner(customer: _customer!),
              ],

              // Already-today warning
              if (_alreadyToday) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.wash.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: context.wash.warning.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: context.wash.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already logged today — double tap?',
                          style: TextStyle(
                              color: context.wash.warning, fontSize: 14),
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
        color: context.wash.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.wash.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.wash.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.repeat, color: context.wash.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning customer · ${customer.visitCount} visits',
                  style: TextStyle(
                    color: context.wash.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (customer.phone != null)
                  Text(
                    customer.phone!,
                    style: TextStyle(
                        color: context.wash.textSecondary, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
