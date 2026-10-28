import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/job.dart';
import '../state/app_state.dart';

typedef FilterResult = ({List<String> countries, bool remoteOnly});

/// Bottom sheet de filtros: países (multi) + solo remoto.
Future<FilterResult?> showFilterSheet(
  BuildContext context, {
  required List<String> selected,
  required bool remoteOnly,
}) {
  return showModalBottomSheet<FilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FilterSheet(initial: selected, initialRemote: remoteOnly),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.initialRemote});

  final List<String> initial;
  final bool initialRemote;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _selected = widget.initial.toSet();
  late bool _remoteOnly = widget.initialRemote;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filtros',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo trabajo remoto'),
              subtitle: const Text('Filtra ofertas 100% remotas'),
              value: _remoteOnly,
              activeColor: AppTheme.green,
              onChanged: (v) => setState(() => _remoteOnly = v),
            ),
            const SizedBox(height: 6),
            const Text('Países',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.countries.map((c) {
                    final code = c['code']!;
                    final sel = _selected.contains(code);
                    return FilterChip(
                      selected: sel,
                      label: Text(c['name']!),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: sel ? Colors.white : Colors.white70,
                        fontWeight:
                            sel ? FontWeight.w800 : FontWeight.w500,
                      ),
                      checkmarkColor: Colors.white,
                      selectedColor: AppTheme.accent.withOpacity(0.85),
                      backgroundColor: AppTheme.bg,
                      side: BorderSide(
                          color: sel ? AppTheme.accent : Colors.white24),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selected.add(code);
                        } else {
                          _selected.remove(code);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final countries =
                    _selected.isEmpty ? const ['xx'] : _selected.toList();
                Navigator.pop(
                    context, (countries: countries, remoteOnly: _remoteOnly));
              },
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet de postulación: genera carta con IA, se edita y se aplica.
Future<String?> showCoverLetterSheet(BuildContext context, Job job) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoverLetterSheet(job: job),
  );
}

class _CoverLetterSheet extends StatefulWidget {
  const _CoverLetterSheet({required this.job});

  final Job job;

  @override
  State<_CoverLetterSheet> createState() => _CoverLetterSheetState();
}

class _CoverLetterSheetState extends State<_CoverLetterSheet> {
  bool _loading = true;
  String? _error;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = context.read<AppState>();
    try {
      final r = await app.api.post('/ai/cover-letter', {
        ...app.aiExtras(),
        'job': {
          'title': widget.job.title,
          'company': widget.job.company,
          'location': widget.job.location,
          'country': widget.job.country,
          'remote': widget.job.remote,
          'description': widget.job.description,
        },
      });
      _ctrl.text = (r['reply'] ?? '').toString();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.accent2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Carta para ${widget.job.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppTheme.accent),
                              SizedBox(height: 14),
                              Text('Ana está escribiendo tu carta…'),
                            ],
                          ),
                        )
                      : _error != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '⚠️ $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _generate,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            )
                          : TextField(
                              controller: _ctrl,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                hintText: 'Tu carta de presentación…',
                              ),
                              style: const TextStyle(
                                  height: 1.5, fontSize: 14.5),
                            ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _loading ? null : () => _generate(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Regenerar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _loading || _error != null
                            ? null
                            : () => Navigator.pop(context, _ctrl.text.trim()),
                        child: const Text('Aplicar ahora'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
