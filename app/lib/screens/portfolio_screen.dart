import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/external_links.dart';
import '../core/theme.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final Future<Map<String, dynamic>> _portfolio = _load();

  Future<Map<String, dynamic>> _load() async =>
      jsonDecode(await rootBundle.loadString('assets/portfolio.json'))
          as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portafolio')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _portfolio,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: snapshot.hasError
                  ? TextButton.icon(
                      onPressed: () => openExternalLink(context, portfolioUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir portafolio en la web'),
                    )
                  : const CircularProgressIndicator(),
            );
          }
          final owner = data['owner'] as Map<String, dynamic>;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.card1, AppTheme.card2],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('TRABAJO / PERFIL PROFESIONAL'),
                    const SizedBox(height: 14),
                    Text(owner['displayName'] as String,
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(owner['headline'] as String),
                    const SizedBox(height: 8),
                    Text(owner['location'] as String,
                        style: const TextStyle(color: AppTheme.accent)),
                    const SizedBox(height: 16),
                    Text(data['narrative'] as String),
                    const SizedBox(height: 8),
                    Text(owner['availability'] as String),
                    const SizedBox(height: 8),
                    Text((owner['languages'] as List).join(' · ')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => openExternalLink(context, portfolioUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver web'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          const ClipboardData(text: portfolioUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enlace copiado')),
                        );
                      }
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Copiar enlace'),
                  ),
                ],
              ),
              _heading(context, 'Proyectos'),
              for (final project in data['projects'] as List)
                Card(
                  color: AppTheme.surface,
                  child: ExpansionTile(
                    title: Text(project['name'] as String),
                    subtitle: Text(project['category'] as String),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(project['summary'] as String),
                      for (final outcome in project['outcomes'] as List)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('• $outcome'),
                        ),
                      const SizedBox(height: 12),
                      _chips(project['stack'] as List),
                    ],
                  ),
                ),
              _heading(context, 'Competencias'),
              for (final group in data['capabilities'] as List) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _eyebrow(group['group'] as String),
                ),
                _chips(group['items'] as List),
              ],
              _heading(context, 'Principios'),
              for (final principle in data['principles'] as List)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $principle'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _heading(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10),
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _eyebrow(String label) => Text(
        label,
        style: const TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );

  Widget _chips(List<dynamic> values) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final value in values) Chip(label: Text(value as String)),
        ],
      );
}
