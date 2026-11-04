import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/external_links.dart';
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
              activeThumbColor: AppTheme.green,
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
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      ),
                      checkmarkColor: Colors.white,
                      selectedColor: AppTheme.accent.withValues(alpha: 0.85),
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
  bool _loading = false;
  String? _error;
  final _ctrl = TextEditingController();

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
    final job = widget.job;
    try {
      final r = await app.api.post('/ai/cover-letter', {
        ...app.aiExtras(),
        'job': {
          'title': job.title,
          'company': job.company,
          'location': job.location,
          'country': job.country,
          'remote': job.remote,
          'description': job.description,
        },
      });
      if (!mounted) return;
      final letter = (r['reply'] ?? '').toString().trim();
      if (letter.isEmpty) throw StateError('Respuesta vacía');
      _ctrl.text = letter;
    } catch (_) {
      _error = 'No se pudo generar la carta. Puedes escribirla aquí.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addPortfolio() {
    if (_ctrl.text.contains(portfolioUrl)) return;
    _ctrl.text = [
      if (_ctrl.text.trim().isNotEmpty) _ctrl.text.trim(),
      'Portafolio de Nelson Vera: $portfolioUrl',
    ].join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            children: [
              Text(
                'Preparar postulación',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text('${widget.job.title} · ${widget.job.company}'),
              const SizedBox(height: 12),
              const Text(
                  'La carta es opcional. Completa el formulario en el sitio de la oferta.'),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                readOnly: _loading,
                minLines: 4,
                maxLines: 8,
                decoration:
                    const InputDecoration(labelText: 'Carta de presentación'),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Text(_error!),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generar con Ana'),
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : _addPortfolio,
                    icon: const Icon(Icons.link),
                    label: const Text('Añadir portafolio'),
                  ),
                ],
              ),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pop(context, _ctrl.text.trim()),
                child: const Text('Guardar y abrir oferta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
