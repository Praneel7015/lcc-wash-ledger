// Screen 3: capture the vehicle front photo (damage reference + vehicle type).
// Flow: take/upload photo → preview with retake/proceed → next screen.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../widgets/worker_app_bar.dart';

class CaptureFrontScreen extends StatefulWidget {
  final String plate;
  final List<int> plateImageBytes;

  const CaptureFrontScreen({
    super.key,
    required this.plate,
    required this.plateImageBytes,
  });

  @override
  State<CaptureFrontScreen> createState() => _CaptureFrontScreenState();
}

class _CaptureFrontScreenState extends State<CaptureFrontScreen> {
  final _picker = ImagePicker();
  Uint8List? _previewBytes;
  bool _navigating = false;

  Future<void> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    final bytes = await xFile.readAsBytes();
    if (!mounted) return;
    setState(() => _previewBytes = bytes);
  }

  void _retake() => setState(() => _previewBytes = null);

  void _proceed() {
    if (_previewBytes == null || _navigating) return;
    setState(() => _navigating = true);
    context.push('/worker/type-package', extra: {
      'plate': widget.plate,
      'plateImageBytes': widget.plateImageBytes,
      'frontImageBytes': _previewBytes!.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WashTheme.bg,
      appBar: WorkerAppBar(
        title: 'Vehicle photo',
        subtitle: widget.plate,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _previewBytes == null
              ? _CaptureView(onPick: _pick)
              : _PreviewView(
                  imageBytes: _previewBytes!,
                  navigating: _navigating,
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
        Center(
          child: Container(
            width: 280,
            height: 200,
            decoration: BoxDecoration(
              color: WashTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WashTheme.border, width: 2),
            ),
            child: const Icon(Icons.camera_front_rounded,
                size: 80, color: WashTheme.textMuted),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Photo of the whole vehicle',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: WashTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Used for vehicle type detection\nand damage dispute reference',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: WashTheme.textSecondary, fontSize: 14, height: 1.5),
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
  final bool navigating;
  final VoidCallback onRetake;
  final VoidCallback onProceed;

  const _PreviewView({
    required this.imageBytes,
    required this.navigating,
    required this.onRetake,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        // Photo preview
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                imageBytes,
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.52,
                fit: BoxFit.cover,
              ),
            ),

            // × retake button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: navigating ? null : onRetake,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),

            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: WashTheme.accent.withValues(alpha: 0.7),
                        width: 1.5),
                  ),
                  child: const Text(
                    'Full vehicle visible? No major obstructions?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: WashTheme.textMuted),
            const SizedBox(width: 6),
            const Text(
              'Tap × to retake if the vehicle is not fully visible',
              style: TextStyle(color: WashTheme.textMuted, fontSize: 12),
            ),
          ],
        ),

        const Spacer(),

        ElevatedButton(
          onPressed: navigating ? null : onProceed,
          child: navigating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: WashTheme.bg),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Photo looks good — Next'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: navigating ? null : onRetake,
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: const Text('Retake Photo'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
