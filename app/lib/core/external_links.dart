import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const portfolioUrl = 'https://trabajo-sigma.vercel.app/';

Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // The device may not have a handler for this URL.
    }
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el enlace.')),
    );
  }
}
