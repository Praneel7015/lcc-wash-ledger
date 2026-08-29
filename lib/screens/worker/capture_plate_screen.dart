// Screen 1: capture photo of the vehicle's front (plate visible).
// Flow: take/upload photo → preview with retake/proceed → OCR → confirm screen.

import 'dart:typed_data';

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
  final _picker = ImagePicker();

  // Once a photo is taken, stored here for preview
  Uint8List? _previewBytes;
  bool _processing = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    final bytes = await xFile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _previewBytes = bytes;
      _error = null;
    });
  }

  void _retake() => setState(() {
        _previewBytes = null;
        _error = null;
      });

  Future<void> _proceed() async {
    if (_previewBytes == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final ocr = ref.read(ocrServiceProvider);
      final text = await ocr.extractPlate(_previewBytes!);
      if (!mounted) return;
      context.push('/worker/confirm-plate', extra: {
        'imageBytes': _previewBytes!.toList(),
        'ocrText': text,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not read plate. Tap Next to enter it manually.');
        // Still allow proceeding with empty OCR text
        context.push('/worker/confirm-plate', extra: {
          'imageBytes': _previewBytes!.toList(),
          'ocrText': '',
        });
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: const WorkerAppBar(title: 'Plate photo'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _previewBytes == null
              ? _CaptureView(onPick: _pick)
              : _PreviewView(
                  imageBytes: _previewBytes!,
                  processing: _processing,
                  error: _error,
                  onRetake: _retake,
                  onProceed: _proceed,
                ),
        ),
      ),
    );
  }
}

// ── Capture state ─────────────────────────────────────────────────────────────

class _CaptureView extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  const _CaptureView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),

        // Guide illustration
        Center(
          child: Container(
            width: 280,
            height: 200,
            decoration: BoxDecoration(
              color: WashTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WashTheme.border, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.directions_car_rounded,
                    size: 80, color: WashTheme.textMuted),
                Positioned(
                  bottom: 24,
                  child: Container(
                    width: 150,
                    height: 34,
                    decoration: BoxDecoration(
                      color: WashTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: WashTheme.accent, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        'NUMBER PLATE',
                        style: TextStyle(
                          color: WashTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        Text(
          'Point the camera at the plate',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: WashTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Make sure the plate is well-lit,\nsharp, and fully in frame',
          textAlign: TextAlign.center,
          style: TextStyle(color: WashTheme.textSecondary, fontSize: 14, height: 1.5),
        ),

        const Spacer(),

        ElevatedButton.icon(
          onPressed: () => onPick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_rounded, size: 22),
          label: const Text('Open Camera'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => onPick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined, size: 20),
          label: const Text('Upload from Gallery'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Preview state ─────────────────────────────────────────────────────────────

class _PreviewView extends StatelessWidget {
  final Uint8List imageBytes;
  final bool processing;
  final String? error;
  final VoidCallback onRetake;
  final VoidCallback onProceed;

  const _PreviewView({
    required this.imageBytes,
    required this.processing,
    required this.error,
    required this.onRetake,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section label
        const Text(
          'CHECK YOUR PHOTO',
          style: TextStyle(
            color: WashTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // Photo preview with retake ×
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                imageBytes,
                width: double.infinity,
                // Fill most of the screen height
                height: MediaQuery.of(context).size.height * 0.52,
                fit: BoxFit.cover,
              ),
            ),

            // Retake (×) button — top-right
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: processing ? null : onRetake,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),

            // Plate guide overlay
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: WashTheme.accent.withValues(alpha: 0.7), width: 1.5),
                  ),
                  child: const Text(
                    'Is the plate clearly visible?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Helper text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: WashTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              'Tap × to retake if the plate is blurry or cut off',
              style: const TextStyle(
                  color: WashTheme.textMuted, fontSize: 12),
            ),
          ],
        ),

        const Spacer(),

        // Error chip (non-blocking — user still proceeds)
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: WashTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: WashTheme.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: WashTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                          color: WashTheme.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Proceed button
        ElevatedButton(
          onPressed: processing ? null : onProceed,
          child: processing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: WashTheme.bg),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Plate looks good — Next'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: processing ? null : onRetake,
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: const Text('Retake Photo'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
