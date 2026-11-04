import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';

class _Msg {
  _Msg(this.role, this.text);
  final String role;
  final String text;
}

/// Chat de búsqueda con Ana y el proveedor elegido por la cuenta.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _msgs = [
    _Msg('assistant', 'Cuéntame qué trabajo estás buscando.'),
  ];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  static const _quickReplies = [
    'Busco trabajo remoto',
    'Soy desarrollador/a junior',
    'Quiero trabajar en otro país',
    'Tengo 2 años de experiencia',
    'Busco empleo en España y México',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (_sending || body.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg('user', body));
      _msgs.add(_Msg('assistant', '…'));
      _sending = true;
    });
    _scrollDown();

    final app = context.read<AppState>();
    final history = [
      for (final m in _msgs)
        if (m.text != '…') {'role': m.role, 'content': m.text},
    ];

    try {
      final r = await app.api.ask('/ai/chat', {
        ...app.aiExtras(),
        'messages': history,
      });
      final reply = (r['reply'] ?? 'Sin respuesta del modelo.').toString();
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _msgs.add(_Msg('assistant', reply));
      });
      _maybeApplyProfile(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _msgs.add(_Msg('assistant',
            '$e\n\nRevisa el estado del proveedor en Conexiones.'));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }

  /// Si Ana emite PROFILE_JSON, convierte la respuesta en filtros de búsqueda.
  void _maybeApplyProfile(String reply) {
    final m = RegExp(r'PROFILE_JSON\s*[:\s]*(\{[\s\S]*?\})').firstMatch(reply);
    if (m == null) return;
    try {
      final prefs = Map<String, dynamic>.from(jsonDecode(m.group(1)!) as Map);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Ana propuso actualizar tus filtros de búsqueda.'),
            action: SnackBarAction(
                label: 'Guardar filtros',
                onPressed: () async {
                  const fields = [
                    'role',
                    'seniority',
                    'countries',
                    'modality',
                    'remote_only',
                    'salary_min',
                    'currency',
                    'skills',
                    'languages',
                    'keywords'
                  ];
                  try {
                    await context.read<AppState>().savePreferences({
                      for (final field in fields)
                        if (prefs.containsKey(field)) field: prefs[field],
                    });
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('No se pudieron guardar los filtros.')),
                      );
                    }
                  }
                }),
          ),
        );
      }
    } catch (_) {
      // JSON incompleto: se ignora, Ana lo reenviará.
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Ana · Asesora IA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Tu búsqueda de empleo',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reiniciar chat',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _msgs.length <= 1 || _sending
                ? null
                : () => setState(() {
                      _msgs
                        ..clear()
                        ..add(_Msg('assistant',
                            'Cuéntame qué trabajo estás buscando.'));
                    }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (app.hasProfile)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.green.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded,
                      color: AppTheme.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Perfil: ${app.preferences['role'] ?? ''} · '
                      'remoto: ${app.preferences['remote_only'] == true ? 'solo remoto' : 'cualquiera'} · '
                      'países: ${(app.preferences['countries'] as List?)?.join(', ') ?? 'xx'}',
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _msgs.length,
              itemBuilder: (context, i) => _bubble(_msgs[i]),
            ),
          ),
          if (_msgs.length <= 2)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _quickReplies
                    .map((q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label:
                                Text(q, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppTheme.surface,
                            side: const BorderSide(color: Colors.white24),
                            onPressed: _sending ? null : () => _send(q),
                          ),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration:
                          const InputDecoration(hintText: 'Escribe a Ana…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.accent,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 22),
                            onPressed: () => _send(_ctrl.text),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.accent.withValues(alpha: 0.9)
              : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          m.text,
          style: const TextStyle(height: 1.4, fontSize: 14),
        ),
      ),
    );
  }
}
