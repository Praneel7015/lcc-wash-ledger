// Screen 3: capture the vehicle front photo (used for type + disputes).

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
  bool _picking = false;
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 960,
        imageQuality: 85,
      );
      if (xFile == null || !mounted) return;
      final bytes = await xFile.readAsBytes();
      if (!mounted) return;
      context.push('/worker/type-package', extra: {
        'plate': widget.plate,
        'plateImageBytes': widget.plateImageBytes,
        'frontImageBytes': bytes.toList(),
      });    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WorkerAppBar(
          title: 'Vehicle photo',
          subtitle: widget.plate),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: Icon(Icons.photo_camera,
                    size: 100, color: WashTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              Text(
                'Take a photo of the\nwhole vehicle',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Used for vehicle type and dispute reference.\nCapture the front clearly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: WashTheme.textSecondary),
              ),
              const Spacer(),
              if (_picking)
                const Center(
                    child:
                        CircularProgressIndicator(color: WashTheme.accent))
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
