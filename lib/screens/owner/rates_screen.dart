// Rate table editor — owner can change prices per vehicle × package.

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
          const SnackBar(content: Text('Rates saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wash rates'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: WashTheme.accent))
                  : const Text('Save',
                      style: TextStyle(
                          color: WashTheme.accent,
                          fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: WashTheme.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WashTheme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: WashTheme.accent.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Changes take effect immediately for new washes.',
                    style: TextStyle(
                        color: WashTheme.accent, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                ...VehicleType.all.map((vt) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Text(VehicleType.emoji(vt),
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              VehicleType.label(vt),
                              style: const TextStyle(
                                color: WashTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...WashPackage.all.map((pkg) {
                        final key = rateKey(vt, pkg);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  WashPackage.label(pkg),
                                  style: const TextStyle(
                                      color: WashTheme.textSecondary,
                                      fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _controllers[key],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: WashTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
                                    prefixStyle: TextStyle(
                                        color: WashTheme.textSecondary,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save all rates'),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
