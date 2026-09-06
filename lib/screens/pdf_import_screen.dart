import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_schedule_parser_service.dart';
import '../widgets/app_motion.dart';
import 'schedule_review_screen.dart';

enum _ImportTarget { timetableOnly, bellOnly, both }

class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  final _picker = ImagePicker();
  final _parser = OcrScheduleParserService();

  _ImportTarget _target = _ImportTarget.both;
  bool _replaceExisting = false;
  bool _busy = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _parser.close();
    super.dispose();
  }

  Future<File> _copyPickedImageToTempFile(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.') ? picked.name.substring(picked.name.lastIndexOf('.')) : '.jpg';
    final tempPath = '${Directory.systemTemp.path}/sir_schedule_${DateTime.now().microsecondsSinceEpoch}$extension';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _busy = true;
      _statusMessage = 'Opening ${source == ImageSource.camera ? 'camera' : 'gallery'}...';
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (picked == null) {
        setState(() {
          _busy = false;
          _statusMessage = 'No image selected.';
        });
        return;
      }

      setState(() => _statusMessage = 'Reading text from image...');
      File? tempFile;
      try {
        tempFile = await _copyPickedImageToTempFile(picked);
        final result = await _parser.parseImage(tempFile);

        if (!mounted) return;

        setState(() => _busy = false);

        await Navigator.push(
          context,
          buildPageRoute(
            ScheduleReviewScreen(
              initialResult: result,
              importBellTimings: _target != _ImportTarget.timetableOnly,
              importTimetable: _target != _ImportTarget.bellOnly,
              replaceExisting: _replaceExisting,
            ),
          ),
        );

        if (mounted) {
          setState(() {
            _statusMessage = 'Review finished. You can scan another sheet anytime.';
          });
        }
      } finally {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F1), Color(0xFFF5F1EA), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                title: 'Scan / Import',
                subtitle: 'Camera or gallery. OCR runs locally.',
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'What are you scanning?',
                child: Column(
                  children: [
                    RadioListTile<_ImportTarget>(
                      title: const Text('Timetable only'),
                      value: _ImportTarget.timetableOnly,
                      groupValue: _target,
                      onChanged: _busy ? null : (value) => setState(() => _target = value!),
                    ),
                    RadioListTile<_ImportTarget>(
                      title: const Text('Bell timings only'),
                      value: _ImportTarget.bellOnly,
                      groupValue: _target,
                      onChanged: _busy ? null : (value) => setState(() => _target = value!),
                    ),
                    RadioListTile<_ImportTarget>(
                      title: const Text('Both timetable and bell timings'),
                      value: _ImportTarget.both,
                      groupValue: _target,
                      onChanged: _busy ? null : (value) => setState(() => _target = value!),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Replace existing saved data'),
                      subtitle: const Text('Turn on when the school has a new schedule.'),
                      value: _replaceExisting,
                      onChanged: _busy ? null : (value) => setState(() => _replaceExisting = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _scan(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Scan with camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Pick from gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_busy)
                const LinearProgressIndicator(),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_statusMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Before save',
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.fact_check_rounded),
                  title: Text('Review the extracted schedule'),
                  subtitle: Text('You can correct the timetable and bell data before anything is stored on the phone.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF164E63)]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}