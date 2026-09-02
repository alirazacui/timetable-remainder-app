import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/period_slot.dart';
import '../models/timetable_entry.dart';
import '../services/pdf_parser_service.dart';
import '../services/storage_service.dart';

/// Screen that lets the user pick a PDF and automatically import
/// bell timings and / or timetable entries from it.
class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  final _parser = PdfParserService();
  final _storage = StorageService();

  _ImportStep _step = _ImportStep.idle;
  String? _filePath;
  PdfParseResult? _result;
  String _statusMessage = '';

  // What the user wants to import
  bool _importBell = true;
  bool _importTimetable = true;
  bool _replaceExisting = false;

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    setState(() {
      _step = _ImportStep.picking;
      _statusMessage = 'Opening file picker…';
      _result = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
        withReadStream: false,
      );

      if (picked == null || picked.files.isEmpty) {
        setState(() {
          _step = _ImportStep.idle;
          _statusMessage = 'No file selected.';
        });
        return;
      }

      final path = picked.files.single.path;
      if (path == null) {
        setState(() {
          _step = _ImportStep.idle;
          _statusMessage = 'Could not get file path.';
        });
        return;
      }

      setState(() {
        _filePath = path;
        _step = _ImportStep.parsing;
        _statusMessage = 'Reading PDF…';
      });

      final result = await _parser.parseFile(File(path));

      setState(() {
        _result = result;
        _step = result.hasAnything ? _ImportStep.preview : _ImportStep.noData;
        _statusMessage = result.hasAnything
            ? 'Found ${result.bellTimings.length} bell timing(s) and '
                '${result.timetableEntries.length} timetable entry/entries.'
            : 'Nothing useful found in this PDF.';
      });
    } catch (e) {
      setState(() {
        _step = _ImportStep.idle;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_result == null) return;

    setState(() {
      _step = _ImportStep.saving;
      _statusMessage = 'Saving…';
    });

    try {
      if (_importBell && _result!.hasBellTimings) {
        List<PeriodSlot> existing = [];
        if (!_replaceExisting) {
          existing = await _storage.loadPeriods();
        }
        final merged = [...existing, ..._result!.bellTimings];
        await _storage.savePeriods(merged);
      }

      if (_importTimetable && _result!.hasTimetable) {
        List<TimetableEntry> existing = [];
        if (!_replaceExisting) {
          existing = await _storage.loadEntries();
        }
        final merged = [...existing, ..._result!.timetableEntries];
        await _storage.saveEntries(merged);
      }

      setState(() {
        _step = _ImportStep.done;
        _statusMessage = 'Import successful! Go back and tap "Sync notifications".';
      });
    } catch (e) {
      setState(() {
        _step = _ImportStep.preview;
        _statusMessage = 'Save failed: $e';
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Import from PDF'),
        elevation: 2,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(cs),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    switch (_step) {
      case _ImportStep.idle:
      case _ImportStep.picking:
        return _buildIdle(cs);
      case _ImportStep.parsing:
        return _buildLoading(cs, 'Analysing PDF…');
      case _ImportStep.saving:
        return _buildLoading(cs, 'Saving data…');
      case _ImportStep.noData:
        return _buildNoData(cs);
      case _ImportStep.preview:
        return _buildPreview(cs);
      case _ImportStep.done:
        return _buildDone(cs);
    }
  }

  // ─ Idle / landing page ───────────────────────────────────────────────────

  Widget _buildIdle(ColorScheme cs) {
    return Center(
      key: const ValueKey('idle'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                size: 96, color: cs.primary.withOpacity(0.85)),
            const SizedBox(height: 24),
            Text(
              'Import Timetable PDF',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Pick your school\'s timetable or bell-timing PDF and the app '
              'will automatically extract period times and class assignments.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.65)),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickAndParse,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose PDF file'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            _hintCard(),
          ],
        ),
      ),
    );
  }

  Widget _hintCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('💡 Tips for best results',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('• Bell-timing PDFs should contain time ranges like "08:00–08:35".'),
            Text('• Timetable PDFs should list classes like "NUR-N", "Jr. I C".'),
            Text('• You can always edit imported data afterwards.'),
          ],
        ),
      ),
    );
  }

  // ─ Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading(ColorScheme cs, String label) {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 20),
          Text(label),
        ],
      ),
    );
  }

  // ─ No data found ─────────────────────────────────────────────────────────

  Widget _buildNoData(ColorScheme cs) {
    final r = _result!;
    return Center(
      key: const ValueKey('nodata'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 72, color: cs.error),
            const SizedBox(height: 16),
            Text('Nothing found in this PDF',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (r.warnings.isNotEmpty)
              ...r.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $w',
                      style: TextStyle(color: cs.error.withOpacity(0.85))),
                ),
              ),
            const SizedBox(height: 24),
            _rawTextExpander(r.rawText, cs),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickAndParse,
              icon: const Icon(Icons.refresh),
              label: const Text('Try another PDF'),
            ),
          ],
        ),
      ),
    );
  }

  // ─ Preview / confirm ─────────────────────────────────────────────────────

  Widget _buildPreview(ColorScheme cs) {
    final r = _result!;

    return ListView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.all(16),
      children: [
        // File name chip
        if (_filePath != null)
          Chip(
            avatar: const Icon(Icons.insert_drive_file_rounded, size: 18),
            label: Text(
              _filePath!.split('/').last,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 8),

        // Warnings
        if (r.warnings.isNotEmpty) ...[
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: cs.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Text('Warnings',
                        style: TextStyle(
                            color: cs.onErrorContainer,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  ...r.warnings.map((w) => Text('• $w',
                      style: TextStyle(color: cs.onErrorContainer))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Import options
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                CheckboxListTile(
                  title: Text('Import bell timings (${r.bellTimings.length} found)'),
                  value: _importBell && r.hasBellTimings,
                  onChanged: r.hasBellTimings
                      ? (v) => setState(() => _importBell = v ?? true)
                      : null,
                ),
                CheckboxListTile(
                  title: Text(
                      'Import timetable entries (${r.timetableEntries.length} found)'),
                  value: _importTimetable && r.hasTimetable,
                  onChanged: r.hasTimetable
                      ? (v) => setState(() => _importTimetable = v ?? true)
                      : null,
                ),
                const Divider(),
                CheckboxListTile(
                  title: const Text('Replace existing data'),
                  subtitle: const Text(
                      'If OFF, imported data is appended to what you already have.'),
                  value: _replaceExisting,
                  onChanged: (v) => setState(() => _replaceExisting = v ?? false),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Bell timings preview
        if (r.hasBellTimings) ...[
          _sectionHeader('Bell Timings Preview', Icons.schedule_rounded),
          ...r.bellTimings.map((s) => _bellTile(s, context)),
          const SizedBox(height: 12),
        ],

        // Timetable preview
        if (r.hasTimetable) ...[
          _sectionHeader('Timetable Preview', Icons.class_rounded),
          ...r.timetableEntries.map((e) {
            final slot = r.bellTimings
                .where((s) => s.id == e.periodSlotId)
                .firstOrNull;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                  radius: 16,
                  child: Text(_weekdayShort(e.weekday),
                      style: const TextStyle(fontSize: 11))),
              title: Text(e.className),
              subtitle: Text(slot?.label ?? 'Period'),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Raw text expander
        _rawTextExpander(r.rawText, cs),
        const SizedBox(height: 80), // space for FAB
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _bellTile(PeriodSlot s, BuildContext ctx) {
    return ListTile(
      dense: true,
      leading: Icon(
        s.isTeachingPeriod ? Icons.book_rounded : Icons.coffee_rounded,
        size: 20,
      ),
      title: Text('${s.label}  (${s.scheduleType == "Fri" ? "Friday" : "Mon–Thu"})'),
      subtitle: Text(
          '${s.start.format(ctx)} → ${s.end.format(ctx)}'
          '${s.isTeachingPeriod ? "" : "  [non-teaching]"}'),
    );
  }

  Widget _rawTextExpander(String raw, ColorScheme cs) {
    return ExpansionTile(
      leading: const Icon(Icons.raw_on_rounded),
      title: const Text('Raw extracted text (for debugging)'),
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            raw.isEmpty ? '(empty)' : raw,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ─ Done ──────────────────────────────────────────────────────────────────

  Widget _buildDone(ColorScheme cs) {
    return Center(
      key: const ValueKey('done'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 96, color: cs.primary),
            const SizedBox(height: 20),
            Text('Import Complete!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_statusMessage, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Home'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _step = _ImportStep.idle;
                  _result = null;
                  _filePath = null;
                  _statusMessage = '';
                });
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import another PDF'),
            ),
          ],
        ),
      ),
    );
  }

  // ─ FAB ───────────────────────────────────────────────────────────────────

  @override
  Widget build_with_fab(BuildContext context) => throw UnimplementedError();
}

// Override Scaffold to attach the confirm FAB only during preview step.
class _PreviewFab extends StatelessWidget {
  final _ImportStep step;
  final VoidCallback onConfirm;

  const _PreviewFab({required this.step, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    if (step != _ImportStep.preview) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: onConfirm,
      icon: const Icon(Icons.download_done_rounded),
      label: const Text('Import this data'),
    );
  }
}

// We need to use a proper build override to get the FAB.
// The cleanest approach: wrap the Scaffold build in the State class above.
// Let's reorganise — see the _buildScaffold helper below.

extension on _PdfImportScreenState {
  Scaffold _buildScaffold() {
    // This is called from build() — replace the build above.
    throw UnimplementedError('Use _buildFull instead');
  }
}

String _weekdayShort(int wd) {
  const names = {
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
  };
  return names[wd] ?? '?';
}

enum _ImportStep { idle, picking, parsing, preview, noData, saving, done }
