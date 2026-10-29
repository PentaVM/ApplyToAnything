import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _role;
  late final TextEditingController _skillCtrl;
  late final TextEditingController _salaryCtrl;
  late final Set<String> _countries;
  late String _modality;
  late String _seniority;
  late String _currency;
  late bool _remoteOnly;
  List<String> _skills = [];
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().preferences;
    _role = TextEditingController(text: (p['role'] ?? '').toString());
    _skillCtrl = TextEditingController();
    _salaryCtrl =
        TextEditingController(text: (p['salary_min'] ?? '').toString());
    _countries = ((p['countries'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    if (_countries.isEmpty) _countries.add('xx');
    _modality = _pick((p['modality'] ?? '').toString(), AppConstants.modalities);
    _seniority =
        _pick((p['seniority'] ?? '').toString(), AppConstants.seniorities);
    _currency = _pick((p['currency'] ?? 'USD').toString(), AppConstants.currencies);
    _remoteOnly = p['remote_only'] == true;
    _skills = ((p['skills'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _pick(String value, List<String> options) =>
      options.contains(value) ? value : options.first;

  @override
  void dispose() {
    _role.dispose();
    _skillCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _touch() => _dirty = true;

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isEmpty || _skills.contains(s)) return;
    setState(() {
      _skills.add(s);
      _skillCtrl.clear();
      _touch();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final app = context.read<AppState>();
    final salary = int.tryParse(_salaryCtrl.text.trim()) ?? 0;
    try {
      await app.savePreferences({
        'role': _role.text.trim(),
        'skills': _skills,
        'countries': _countries.toList(),
        'modality': _modality,
        'seniority': _seniority,
        'remote_only': _remoteOnly || _modality == 'Remoto',
        'salary_min': salary,
        'currency': _currency,
      });
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Perfil guardado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(user?.email ?? '',
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _section('¿Qué trabajo buscas?'),
          TextField(
            controller: _role,
            onChanged: (_) => _touch(),
            decoration:
                const InputDecoration(hintText: 'Ej. desarrollador web, contador…'),
          ),
          const SizedBox(height: 18),
          _section('Skills (para buscar ofertas)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _skills)
                Chip(
                  label: Text(s, style: const TextStyle(fontSize: 12.5)),
                  backgroundColor: AppTheme.surface,
                  side: const BorderSide(color: Colors.white24),
                  onDeleted: () => setState(() {
                    _skills.remove(s);
                    _touch();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skillCtrl,
                  onSubmitted: (_) => _addSkill(),
                  decoration:
                      const InputDecoration(hintText: 'Añadir skill…'),
                ),
              ),
              IconButton(
                onPressed: _addSkill,
                icon: const Icon(Icons.add_circle_rounded,
                    color: AppTheme.accent2, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _section('Países donde quieres trabajar'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.countries.map((c) {
              final code = c['code']!;
              final sel = _countries.contains(code);
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
                side: BorderSide(color: sel ? AppTheme.accent : Colors.white24),
                onSelected: (v) => setState(() {
                  if (v) {
                    _countries.add(code);
                  } else {
                    _countries.remove(code);
                  }
                  _touch();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _section('Modalidad'),
          DropdownButtonFormField<String>(
            initialValue: _modality,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(),
            items: AppConstants.modalities
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() {
              _modality = v ?? _modality;
              _touch();
            }),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo ofertas remotas'),
            value: _remoteOnly,
            activeThumbColor: AppTheme.green,
            onChanged: (v) => setState(() {
              _remoteOnly = v;
              _touch();
            }),
          ),
          const SizedBox(height: 8),
          _section('Nivel de experiencia'),
          DropdownButtonFormField<String>(
            initialValue: _seniority,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(),
            items: AppConstants.seniorities
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() {
              _seniority = v ?? _seniority;
              _touch();
            }),
          ),
          const SizedBox(height: 18),
          _section('Expectativa salarial mínima'),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Ej. 2000'),
                  onChanged: (_) => _touch(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(),
                  items: AppConstants.currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _currency = v ?? _currency;
                    _touch();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Guardar perfil'),
          ),
          if (_dirty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(
                child: Text('Hay cambios sin guardar',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ),
          const SizedBox(height: 30),
          OutlinedButton(
            onPressed: () => context.read<AppState>().logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppTheme.accent),
            ),
            child: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 24),
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
