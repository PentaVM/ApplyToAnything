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
  });

  final int id;
  final String jobId, title, company, url, source, country, status, createdAt;

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
      );
}
