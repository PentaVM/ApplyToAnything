import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/external_links.dart';
import '../core/theme.dart';
import '../models/application.dart';
import '../state/app_state.dart';
import 'swipe_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Application> _all = [];
  bool _loading = true;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppState>();
      final apps = await fetchApplications(app);
      if (!mounted) return;
      setState(() {
        _all = apps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markApplied(Application a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar envío'),
        content: Text('¿Ya enviaste tu postulación a ${a.company}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, ya la envié'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _update(() => context.read<AppState>().api.patch(
          '/applications/${a.id}',
          {'status': 'applied', 'confirmed_submission': true},
        ));
  }

  Future<void> _update(Future<dynamic> Function() request) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await request();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _viewLetter(Application a) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Carta de presentación'),
          content: SingleChildScrollView(child: SelectableText(a.coverLetter)),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: a.coverLetter));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Carta copiada')),
                  );
                }
              },
              child: const Text('Copiar carta'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final applied = _all.where((a) => a.confirmed).toList();
    final pending =
        _all.where((a) => a.status != 'skipped' && !a.confirmed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis postulaciones',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Enviadas'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60)),
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _list(pending, appliedTab: false),
                    _list(applied, appliedTab: true),
                  ],
                ),
    );
  }

  Widget _list(List<Application> items, {required bool appliedTab}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(appliedTab ? Icons.work_off_outlined : Icons.star_border,
                size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              appliedTab
                  ? 'Aquí verás las postulaciones que confirmes como enviadas.'
                  : 'Guarda una oferta o prepara una postulación desde Empleos.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.5),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final a = items[i];
          return Material(
            color: AppTheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              title: Text(
                a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${a.company} · ${a.source}'
                '${a.createdAt.length >= 10 ? ' · ${a.createdAt.substring(0, 10)}' : ''}'
                '${a.status == 'applied' && !a.confirmed ? '\nRegistro anterior · envío por confirmar' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
              onTap:
                  a.url.isEmpty ? null : () => openExternalLink(context, a.url),
              trailing: PopupMenuButton<String>(
                enabled: !_updating,
                tooltip: 'Opciones de la oferta',
                onSelected: (action) async {
                  switch (action) {
                    case 'open':
                      await openExternalLink(context, a.url);
                    case 'letter':
                      await _viewLetter(a);
                    case 'sent':
                      await _markApplied(a);
                    case 'delete':
                      await _update(() => context.read<AppState>().api.delete(
                            '/applications/${a.id}',
                          ));
                  }
                },
                itemBuilder: (_) => [
                  if (a.url.isNotEmpty)
                    const PopupMenuItem(
                        value: 'open', child: Text('Abrir oferta')),
                  if (a.coverLetter.isNotEmpty)
                    const PopupMenuItem(
                        value: 'letter', child: Text('Ver carta')),
                  if (!appliedTab)
                    const PopupMenuItem(
                        value: 'sent', child: Text('Marcar como enviada')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
