class Application {
  Application({
    required this.id,
    required this.jobId,
    required this.title,
    required this.company,
    required this.url,
    required this.source,
    required this.country,
    required this.status,
    required this.createdAt,
    this.coverLetter = '',
    this.method = '',
  });

  final int id;
  final String jobId, title, company, url, source, country, status, createdAt;
  final String coverLetter;
  final String method;

  bool get confirmed => status == 'applied' && method == 'manual_confirmation';

  factory Application.fromJson(Map<String, dynamic> j) => Application(
        id: (j['id'] as num?)?.toInt() ?? 0,
        jobId: (j['job_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        company: (j['company'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        country: (j['country'] ?? '').toString(),
        status: (j['status'] ?? 'liked').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        coverLetter: (j['cover_letter'] ?? '').toString(),
        method: (j['method'] ?? '').toString(),
      );
}
