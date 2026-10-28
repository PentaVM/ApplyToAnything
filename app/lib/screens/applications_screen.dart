import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    final app = context.read<AppState>();
    try {
      await app.api.patch('/applications/${a.id}', {'status': 'applied'});
      if (a.url.isNotEmpty) {
        try {
          await launchUrl(Uri.parse(a.url),
              mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(Application a) async {
    final app = context.read<AppState>();
    try {
      await app.api.delete('/applications/${a.id}');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final applied = _all.where((a) => a.status == 'applied').toList();
    final liked = _all.where((a) => a.status == 'liked').toList();

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
            Tab(text: 'Aplicadas'),
            Tab(text: 'Guardadas ⭐'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
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
                    _list(applied, appliedTab: true),
                    _list(liked, appliedTab: false),
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
                  ? 'Aún no has aplicado a ninguna oferta.\n¡Desliza a la derecha en Empleos!'
                  : 'No tienes ofertas guardadas.\nDesliza hacia arriba para guardar.',
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
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
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
                '${a.company} · ${a.source}${a.createdAt.length >= 10 ? ' · ${a.createdAt.substring(0, 10)}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!appliedTab)
                    IconButton(
                      tooltip: 'Aplicar ahora',
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          color: AppTheme.green),
                      onPressed: () => _markApplied(a),
                    ),
                  if (appliedTab && a.url.isNotEmpty)
                    IconButton(
                      tooltip: 'Abrir oferta',
                      icon: const Icon(Icons.open_in_new_rounded,
                          color: AppTheme.accent2),
                      onPressed: () {
                        launchUrl(Uri.parse(a.url),
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white38, size: 20),
                    onPressed: () => _delete(a),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
