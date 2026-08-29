// Rate table editor — owner can customize pricing per vehicle type × package.
// Clean desktop and mobile responsive layout.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/providers.dart';

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final svc = ref.read(firestoreServiceProvider);
    final rates = await svc.loadRates();
    final controllers = <String, TextEditingController>{};
    for (final vt in VehicleType.all) {
      for (final pkg in WashPackage.all) {
        final key = rateKey(vt, pkg);
        controllers[key] =
            TextEditingController(text: (rates[key] ?? 0).toString());
      }
    }
    if (mounted) {
      setState(() {
        _controllers = controllers;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      for (final vt in VehicleType.all) {
        for (final pkg in WashPackage.all) {
          final key = rateKey(vt, pkg);
          final val = int.tryParse(_controllers[key]?.text ?? '0') ?? 0;
          await svc.setRate(vt, pkg, val);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: WashTheme.success, size: 20),
                SizedBox(width: 10),
                Text('Wash rates updated successfully!'),
              ],
            ),
            backgroundColor: WashTheme.surfaceHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        title: const Text('Wash Rate Matrix'),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save Rates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WashTheme.accent,
                  foregroundColor: WashTheme.bg,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: WashTheme.accent))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WashTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: WashTheme.accent.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: WashTheme.accent, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Rates set here automatically determine pricing on worker mobile intake devices.',
                              style: TextStyle(
                                color: WashTheme.textPrimary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ...VehicleType.all.map((vt) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: WashTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WashTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(VehicleType.emoji(vt),
                                    style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Text(
                                  VehicleType.label(vt),
                                  style: const TextStyle(
                                    color: WashTheme.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                          ...WashPackage.forVehicle(vt).map((pkg) {
                              final key = rateKey(vt, pkg);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            WashPackage.label(pkg),
                                            style: const TextStyle(
                                              color: WashTheme.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            WashPackage.description(pkg),
                                            style: const TextStyle(
                                              color: WashTheme.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 130,
                                      child: TextField(
                                        controller: _controllers[key],
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: WashTheme.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: const Padding(
                                            padding: EdgeInsets.only(
                                                left: 12, top: 12),
                                            child: Text(
                                              '₹',
                                              style: TextStyle(
                                                color: WashTheme.accent,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 12),
                                          fillColor: WashTheme.surfaceHigh,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: WashTheme.border),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}
