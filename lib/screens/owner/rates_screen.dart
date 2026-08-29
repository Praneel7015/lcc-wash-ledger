// Rate table editor + package manager — owner dashboard.
// Tab 1 (Rates): vehicle type × package grid loaded dynamically from Firestore.
// Tab 2 (Packages): add / edit / delete packages with full CRUD.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/packages_provider.dart';
import '../../services/providers.dart';

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: AppBar(
        title: const Text('Wash Rates & Packages'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: WashTheme.accent,
          labelColor: WashTheme.accent,
          unselectedLabelColor: WashTheme.textSecondary,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Inter'),
          tabs: const [
            Tab(text: 'Rates'),
            Tab(text: 'Packages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RatesTab(),
          _PackagesTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RATES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _RatesTab extends ConsumerStatefulWidget {
  const _RatesTab();

  @override
  ConsumerState<_RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends ConsumerState<_RatesTab> {
  Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _packages = [];

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
    final results = await Future.wait([svc.loadRates(), svc.loadPackages()]);
    final rates = results[0] as Map<String, int>;
    final packages = results[1] as List<Map<String, dynamic>>;

    final controllers = <String, TextEditingController>{};
    for (final vt in VehicleType.all) {
      for (final pkg in packages) {
        final key = rateKey(vt, pkg['id'] as String);
        controllers[key] =
            TextEditingController(text: (rates[key] ?? 0).toString());
      }
    }
    if (mounted) {
      setState(() {
        _controllers = controllers;
        _packages = packages;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      for (final vt in VehicleType.all) {
        for (final pkg in _packages) {
          final pkgId = pkg['id'] as String;
          final vehicleTypes = List<String>.from(pkg['vehicleTypes'] as List);
          if (!vehicleTypes.contains(vt)) continue;
          final key = rateKey(vt, pkgId);
          final val = int.tryParse(_controllers[key]?.text ?? '0') ?? 0;
          await svc.setRate(vt, pkgId, val);
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
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: WashTheme.accent));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WashTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: WashTheme.accent.withValues(alpha: 0.25)),
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
              final applicablePackages = _packages
                  .where((p) =>
                      (p['vehicleTypes'] as List<dynamic>).contains(vt))
                  .toList();
              if (applicablePackages.isEmpty) return const SizedBox.shrink();

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
                    ...applicablePackages.map((pkg) {
                      final pkgId = pkg['id'] as String;
                      final key = rateKey(vt, pkgId);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pkg['label'] as String,
                                    style: const TextStyle(
                                      color: WashTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if ((pkg['description'] as String)
                                      .isNotEmpty)
                                    Text(
                                      pkg['description'] as String,
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
                                controller: _controllers[key] ??
                                    TextEditingController(text: '0'),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: WashTheme.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Padding(
                                    padding:
                                        EdgeInsets.only(left: 12, top: 12),
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
                                    borderRadius: BorderRadius.circular(10),
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

            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save Rates'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PACKAGES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _PackagesTab extends ConsumerStatefulWidget {
  const _PackagesTab();

  @override
  ConsumerState<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<_PackagesTab> {
  List<Map<String, dynamic>>? _packages;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final svc = ref.read(firestoreServiceProvider);
    final list = await svc.loadPackages();
    // Invalidate the shared provider so worker screen picks up changes
    ref.invalidate(packagesProvider);
    if (mounted) setState(() { _packages = list; _loading = false; });
  }

  void _showPackageSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WashTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PackageFormSheet(
        existing: existing,
        existingIds:
            _packages?.map((p) => p['id'] as String).toSet() ?? const {},
        onSaved: _reload,
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> pkg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WashTheme.surfaceHigh,
        title: const Text('Delete package?',
            style: TextStyle(color: WashTheme.textPrimary)),
        content: Text(
          'This will permanently remove "${pkg['label']}" and all its rates.',
          style: const TextStyle(color: WashTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: WashTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: WashTheme.danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final svc = ref.read(firestoreServiceProvider);
    await svc.deletePackage(pkg['id'] as String);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete_rounded, color: WashTheme.danger, size: 18),
              const SizedBox(width: 10),
              Text('"${pkg['label']}" deleted.'),
            ],
          ),
          backgroundColor: WashTheme.surfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WashTheme.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPackageSheet(),
        backgroundColor: WashTheme.accent,
        foregroundColor: WashTheme.bg,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Package',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: WashTheme.accent))
          : (_packages == null || _packages!.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.car_repair_rounded,
                          color: WashTheme.textMuted, size: 48),
                      const SizedBox(height: 16),
                      const Text('No packages yet.',
                          style: TextStyle(
                              color: WashTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => _showPackageSheet(),
                          child: const Text('Add first package',
                              style: TextStyle(color: WashTheme.accent))),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _packages!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final pkg = _packages![i];
                        final vtLabels = (pkg['vehicleTypes'] as List<dynamic>)
                            .map((v) => VehicleType.label(v as String))
                            .join(', ');
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: WashTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: WashTheme.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order badge
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: WashTheme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${pkg['order']}',
                                  style: const TextStyle(
                                    color: WashTheme.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pkg['label'] as String,
                                      style: const TextStyle(
                                        color: WashTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if ((pkg['description'] as String)
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        pkg['description'] as String,
                                        style: const TextStyle(
                                          color: WashTheme.textSecondary,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_car_rounded,
                                            size: 13,
                                            color: WashTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          vtLabels.isNotEmpty
                                              ? vtLabels
                                              : 'No vehicle types',
                                          style: const TextStyle(
                                            color: WashTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: WashTheme.surfaceHigh,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'ID: ${pkg['id']}',
                                            style: const TextStyle(
                                              color: WashTheme.textMuted,
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _showPackageSheet(existing: pkg),
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 18),
                                    color: WashTheme.textSecondary,
                                    tooltip: 'Edit',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    onPressed: () => _delete(pkg),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18),
                                    color: WashTheme.danger,
                                    tooltip: 'Delete',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PACKAGE FORM BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _PackageFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final Set<String> existingIds;
  final VoidCallback onSaved;

  const _PackageFormSheet({
    required this.existing,
    required this.existingIds,
    required this.onSaved,
  });

  @override
  ConsumerState<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends ConsumerState<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _orderCtrl;
  late List<String> _vehicleTypes;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idCtrl = TextEditingController(text: e?['id'] as String? ?? '');
    _labelCtrl = TextEditingController(text: e?['label'] as String? ?? '');
    _descCtrl =
        TextEditingController(text: e?['description'] as String? ?? '');
    _orderCtrl = TextEditingController(
        text: (e?['order'] as int?)?.toString() ?? '1');
    _vehicleTypes =
        List<String>.from(e?['vehicleTypes'] as List? ?? []);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  /// Auto-generate a snake_case ID from the label
  void _autoSuggestId(String label) {
    if (!_isNew) return;
    final suggested = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    _idCtrl.text = suggested;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      await svc.savePackage(
        _idCtrl.text.trim(),
        _labelCtrl.text.trim(),
        _descCtrl.text.trim(),
        List<String>.from(_vehicleTypes),
        int.tryParse(_orderCtrl.text.trim()) ?? 1,
      );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: WashTheme.success, size: 18),
                const SizedBox(width: 10),
                Text(_isNew ? 'Package created!' : 'Package updated!'),
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

  Widget _vtCheckbox(String vtId) {
    final checked = _vehicleTypes.contains(vtId);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${VehicleType.emoji(vtId)}  ${VehicleType.label(vtId)}',
        style: const TextStyle(color: WashTheme.textPrimary, fontSize: 14),
      ),
      value: checked,
      activeColor: WashTheme.accent,
      checkColor: WashTheme.bg,
      onChanged: (val) => setState(() {
        if (val == true) {
          _vehicleTypes.add(vtId);
        } else {
          _vehicleTypes.remove(vtId);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WashTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isNew ? 'New Package' : 'Edit Package',
                style: const TextStyle(
                  color: WashTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),

              // Package ID (new only)
              if (_isNew) ...[
                TextFormField(
                  controller: _idCtrl,
                  style: const TextStyle(
                      color: WashTheme.textPrimary, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'Package ID (snake_case)',
                    hintText: 'e.g. premium_wash',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (widget.existingIds.contains(v.trim())) {
                      return 'ID already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Label
              TextFormField(
                controller: _labelCtrl,
                style: const TextStyle(color: WashTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Label *'),
                onChanged: _autoSuggestId,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: WashTheme.textPrimary),
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Vehicle types
              const Text(
                'Applies to',
                style: TextStyle(
                    color: WashTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...VehicleType.all.map(_vtCheckbox),
              const SizedBox(height: 16),

              // Order
              TextFormField(
                controller: _orderCtrl,
                style: const TextStyle(color: WashTheme.textPrimary),
                decoration:
                    const InputDecoration(labelText: 'Display order (number)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving
                    ? 'Saving…'
                    : (_isNew ? 'Create Package' : 'Save Changes')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
