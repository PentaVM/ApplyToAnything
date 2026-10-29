import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/application.dart';
import '../models/job.dart';
import '../state/app_state.dart';
import '../widgets/sheets.dart';
import '../widgets/swipe_deck.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final SwipeDeckController _deck = SwipeDeckController();

  List<Job> _jobs = [];
  final Set<String> _seen = {};
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  String? _queryInfo;

  List<String> _countries = const ['xx'];
  bool _remoteOnly = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final app = context.read<AppState>();
    final c = app.preferences['countries'];
    if (c is List && c.isNotEmpty) {
      _countries = c.map((e) => e.toString()).toList();
    }
    _remoteOnly = app.preferences['remote_only'] == true;
    try {
      final apps = await fetchApplications(app);
      for (final a in apps) {
        _seen.add(a.jobId);
      }
    } catch (_) {
      // Si falla, el mazo se muestra igual.
    }
    if (mounted) await _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (reset) _page = 1;

    final app = context.read<AppState>();
    try {
      final r = await app.api.get('/jobs/search', {
        'remote': _remoteOnly ? 'only' : 'any',
        'page': '$_page',
        'countries': _countries.join(','),
      });
      if (!mounted) return;
      final list = ((r['jobs'] as List?) ?? [])
          .map((e) => Job.fromJson((e as Map).cast<String, dynamic>()))
          .where((j) => !_seen.contains(j.id))
          .toList();
      final info = (r['query'] as Map?)?['q'];
      setState(() {
        if (reset) {
          _jobs = list;
        } else {
          _jobs.addAll(list);
        }
        _page += 1;
        _loading = false;
        _loadedOnce = true;
        _queryInfo = (info == null || info.toString().isEmpty)
            ? null
            : 'Búsqueda: «$info»';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadedOnce = true;
      });
    }
  }

  Future<void> _openFilters() async {
    final res = await showFilterSheet(
      context,
      selected: _countries,
      remoteOnly: _remoteOnly,
    );
    if (res == null || !mounted) return;
    setState(() {
      _countries = res.countries;
      _remoteOnly = res.remoteOnly;
    });
    final app = context.read<AppState>();
    app.setLocalPreferences({'countries': _countries, 'remote_only': _remoteOnly});
    app
        .savePreferences({'countries': _countries, 'remote_only': _remoteOnly})
        .catchError((_) {});
    if (mounted) await _load(reset: true);
  }

  Future<void> _onDecide(Job job, SwipeDir dir) async {
    setState(() => _jobs.remove(job));

    if (dir == SwipeDir.left) {
      await _saveApp(job, 'skipped');
      return;
    }
    if (dir == SwipeDir.up) {
      await _saveApp(job, 'liked');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⭐ Oferta guardada')),
        );
      }
      return;
    }

    // Swipe derecha → flujo de postulación con carta de la IA
    final letter = await showCoverLetterSheet(context, job);
    if (letter == null || letter.isEmpty) return;
    await _saveApp(job, 'applied', letter: letter);
    if (job.url.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(job.url),
            mode: LaunchMode.externalApplication);
      } catch (_) {
        // La oferta se registra igual; el navegador puede bloquear el intent.
      }
    }
  }

  Future<void> _saveApp(Job job, String status, {String letter = ''}) async {
    final app = context.read<AppState>();
    try {
      await app.api.post('/applications', {
        'job_id': job.id,
        'title': job.title,
        'company': job.company,
        'url': job.url,
        'source': job.source,
        'country': job.country,
        'status': status,
        'method': status == 'applied' ? 'external_url' : 'none',
        'cover_letter': letter,
      });
      _seen.add(job.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final needsProfile = !app.hasProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ApplyToAnything',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openFilters,
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          if (needsProfile)
            _banner(
              icon: Icons.smart_toy_rounded,
              text: 'Habla con Ana (pestaña IA) para definir tu búsqueda '
                  'y obtener ofertas a tu medida.',
              color: AppTheme.accent2,
            ),
          if (_queryInfo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  Text(_queryInfo!,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          Expanded(
            child: !_loadedOnce && _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : _error != null && _jobs.isEmpty
                    ? _errorView()
                    : RefreshIndicator(
                        color: AppTheme.accent,
                        onRefresh: () => _load(reset: true),
                        child: _jobs.isEmpty && !_loading
                            ? ListView(
                                children: [
                                  const SizedBox(height: 160),
                                  const SwipeDeckFallbackEmpty(),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: () => _load(reset: true),
                                    child: const Text('Cargar más ofertas'),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              )
                            : SwipeDeck(
                                jobs: _jobs,
                                controller: _deck,
                                onDecide: _onDecide,
                              ),
                      ),
          ),
          if (_loading && _loadedOnce)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          _actionRow(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 60, color: Colors.white24),
            const SizedBox(height: 14),
            Text('$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13.5)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => _load(reset: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow() {
    Widget btn(IconData icon, Color color, String tooltip, VoidCallback onTap,
        {bool big = false}) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: big ? 66 : 56,
            height: big ? 66 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: big ? 32 : 27),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(Icons.close_rounded, AppTheme.accent, 'Paso',
            () => _deck.swipe(SwipeDir.left)),
        btn(Icons.star_rounded, AppTheme.accent2, 'Guardar',
            () => _deck.swipe(SwipeDir.up), big: true),
        btn(Icons.check_rounded, AppTheme.green, 'Aplicar',
            () => _deck.swipe(SwipeDir.right)),
      ],
    );
  }

  Widget _banner(
      {required IconData icon,
      required String text,
      required Color color}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Placeholder visual cuando el mazo queda vacío (usado dentro de un ListView).
class SwipeDeckFallbackEmpty extends StatelessWidget {
  const SwipeDeckFallbackEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.travel_explore_rounded, size: 72, color: Colors.white24),
        SizedBox(height: 14),
        Text(
          'No hay más ofertas por ahora',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 6),
        Text(
          'Prueba con otros filtros o revisa tu perfil de búsqueda.',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}

/// Carga la lista de postulaciones (ids ya vistos) — utilidad compartida.
Future<List<Application>> fetchApplications(AppState app) async {
  final r = await app.api.get('/applications');
  return ((r['applications'] as List?) ?? [])
      .map((e) => Application.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
}
