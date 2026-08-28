// Screen 1: capture photo of the vehicle's front (plate visible).
// Shows a plate-shaped guide overlay. Camera first; gallery fallback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../widgets/worker_app_bar.dart';

class CapturePlateScreen extends ConsumerStatefulWidget {
  const CapturePlateScreen({super.key});

  @override
  ConsumerState<CapturePlateScreen> createState() => _CapturePlateScreenState();
}

class _CapturePlateScreenState extends ConsumerState<CapturePlateScreen> {
  bool _processing = false;
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final bytes = await xFile.readAsBytes();
      final ocr = ref.read(ocrServiceProvider);
      final text = await ocr.extractPlate(bytes);
      if (!mounted) return;
      context.push('/worker/confirm-plate', extra: {
        'imageBytes': bytes.toList(),
        'ocrText': text,
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WorkerAppBar(title: 'Capture plate'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Guide illustration
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 280,
                      height: 200,
                      decoration: BoxDecoration(
                        color: WashTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: WashTheme.border, width: 2),
                      ),
                      child: const Icon(Icons.directions_car,
                          size: 80, color: WashTheme.textSecondary),
                    ),
                    // Plate overlay guide
                    Positioned(
                      bottom: 24,
                      child: _PlateGuide(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Point camera at the\nnumber plate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure the plate is well-lit and fully visible',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const Spacer(),

              if (_processing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: WashTheme.accent),
                      SizedBox(height: 12),
                      Text('Reading plate…',
                          style: TextStyle(color: WashTheme.textSecondary)),
                    ],
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take photo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload from gallery'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 32,
      decoration: BoxDecoration(
        color: WashTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: WashTheme.accent, width: 2),
      ),
      child: const Center(
        child: Text(
          'PLATE',
          style: TextStyle(
            color: WashTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
