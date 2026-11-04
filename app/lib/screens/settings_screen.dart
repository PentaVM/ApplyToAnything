import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _backend =
      TextEditingController(text: context.read<AppState>().backendUrl);
  late final TextEditingController _model =
      TextEditingController(text: context.read<AppState>().omniModel);
  late final TextEditingController _key =
      TextEditingController(text: context.read<AppState>().omniKey);
  bool _testing = false;
  bool _saving = false;
  String? _testResult;

  @override
  void dispose() {
    _backend.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _testing) return;
    setState(() => _saving = true);
    final app = context.read<AppState>();
    try {
      final next = AppState.normalizeBackendUrl(_backend.text);
      final reconnect = next != app.backendUrl && app.user != null;
      await app.setBackendUrl(next);
      await app.setOmniConfig(_model.text, _key.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reconnect
            ? 'Conexión guardada. Vuelve a iniciar sesión.'
            : 'Ajustes guardados'),
      ));
      if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _testResult = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final client = ApiClient(AppState.normalizeBackendUrl(_backend.text));
      final h = await client.get('/health').timeout(const Duration(seconds: 8));
      if (h is! Map || h['app'] != 'ApplyToAnything' || h['status'] != 'ok') {
        throw ApiException(
            'La URL no corresponde al backend de ApplyToAnything.');
      }
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'Backend OK · OmniRoute: ${h['omniroute_base']} · '
            'modelo: ${h['omniroute_model']} · '
            'Adzuna: ${h['adzuna'] == true ? 'configurado' : 'sin claves'} · '
            'Jooble: ${h['jooble'] == true ? 'configurado' : 'sin claves'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = '⚠️ $e';
      });
    }
  }

  Future<void> _viewSystemPrompt() async {
    try {
      final text = await rootBundle.loadString('assets/system.md');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('system.md'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo abrir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _section('Backend de ApplyToAnything'),
          TextField(
            controller: _backend,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: AppConstants.defaultBackendUrl,
            ),
          ),
          const Text(
            'En el emulador Android usa http://10.0.2.2:8000 (localhost de tu '
            'PC). En un dispositivo físico usa la IP LAN de tu PC.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 22),
          _section('Modelo y clave API'),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Modelo (opcional)',
              hintText: AppConstants.defaultOmniModel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Clave API (opcional)',
              hintText: 'Solo durante esta sesión',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Elige el proveedor en Conexiones. Si usas un conector, '
            'configura el modelo y las credenciales en el equipo que lo ejecuta.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing || _saving ? null : _test,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Probar conexión'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _testing || _saving ? null : _save,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 14),
            Text(_testResult!,
                style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _viewSystemPrompt,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Ver system.md (prompt de la IA)'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}
