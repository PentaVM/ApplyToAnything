import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/external_links.dart';
import '../state/app_state.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  static const _labels = {
    'auto': 'OmniRoute del servidor',
    'codex': 'Codex',
    'claude': 'Claude Code',
    'antigravity': 'Antigravity',
    'omniroute': 'OmniRoute en tu equipo',
    'api': 'API en tu equipo',
    'custom': 'Conector personalizado',
    'api_key': 'Clave API directa',
  };
  String _selected = 'auto';
  String _saved = 'auto';
  Map<String, dynamic>? _paired;
  String? _code;
  String? _error;
  bool _busy = false;

  bool get _local => _selected != 'auto' && _selected != 'api_key';

  @override
  void initState() {
    super.initState();
    if (context.read<AppState>().user != null) _run(_load);
  }

  Future<void> _load() async {
    final data = await context.read<AppState>().api.get('/ai/connectors');
    if (!mounted) return;
    final provider = data['selected'] as String;
    _selected = _saved = _labels.containsKey(provider) ? provider : 'auto';
    _paired = Map<String, dynamic>.from(data['paired'] as Map);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pair() async {
    final api = context.read<AppState>().api;
    if (_paired?.containsKey(_selected) == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reemplazar código'),
          content: const Text('El código anterior dejará de funcionar.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reemplazar')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final result = await api.post('/ai/connectors', {'provider': _selected});
    if (!mounted) return;
    _code = result['token'] as String;
    _paired?[_selected] = false;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: const Text('Conexiones de IA')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Usa la misma cuenta en la web y en Android.'),
          TextButton.icon(
            onPressed: () => openExternalLink(context, app.backendUrl),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Abrir ApplyToAnything en el navegador'),
          ),
          if (app.user != null) ...[
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_paired == null)
              TextButton(
                  onPressed: _busy ? null : () => _run(_load),
                  child: const Text('Cargar proveedores')),
            if (_paired != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_selected),
                initialValue: _selected,
                decoration: const InputDecoration(labelText: 'Proveedor de IA'),
                items: [
                  for (final entry in _labels.entries)
                    DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _selected = value ?? _saved;
                          _code = null;
                        }),
              ),
              const SizedBox(height: 12),
              Text(_local
                  ? (_paired?[_selected] == true
                      ? 'Conector en línea'
                      : 'Conector sin conexión')
                  : (_selected == 'api_key'
                      ? 'Introduce la clave y el modelo en Ajustes.'
                      : 'Usa OmniRoute del backend.')),
              Text('Activo en tu cuenta: ${_labels[_saved]}'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || _saved == _selected
                    ? null
                    : () => _run(() async {
                          await app.api
                              .put('/ai/provider', {'provider': _selected});
                          _saved = _selected;
                        }),
                child: const Text('Usar este proveedor'),
              ),
              if (_local)
                Wrap(
                  children: [
                    TextButton(
                        onPressed: _busy ? null : () => _run(_pair),
                        child: const Text('Generar código')),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await app.api
                                      .delete('/ai/connectors/$_selected');
                                  _paired?.remove(_selected);
                                  _code = null;
                                }),
                        child: const Text('Desconectar')),
                    TextButton(
                        onPressed: _busy ? null : () => _run(_load),
                        child: const Text('Actualizar estado')),
                  ],
                ),
              if (code != null) ...[
                const Text(
                    'Ejecuta este comando en el equipo del proveedor y pega el código cuando se solicite.'),
                SelectableText(
                    'python connector.py $_selected --server ${app.backendUrl}'),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código de conexión'),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
