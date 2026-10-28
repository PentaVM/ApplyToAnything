import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/job.dart';

/// Tarjeta de empleo con el estilo visual del mazo.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.top = false});

  final Job job;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.card1, AppTheme.card2],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _chip(job.source.toUpperCase(), AppTheme.accent),
                  const SizedBox(width: 8),
                  if (job.remote) _chip('REMOTO', AppTheme.green),
                  const Spacer(),
                  Text(
                    AppConstants.countryName(job.country),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                job.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                job.company,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location.isEmpty ? 'Sin ubicación' : job.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  if (job.salary.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.payments_outlined, size: 16, color: Colors.white54),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        job.salary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (job.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: job.tags
                      .take(6)
                      .map((t) => _chip(t, AppTheme.accent2, small: true))
                      .toList(),
                ),
              if (job.tags.isNotEmpty) const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    job.description.isEmpty
                        ? 'Sin descripción disponible. Abre la oferta para ver más.'
                        : job.description,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13.5, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, {bool small = false}) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
