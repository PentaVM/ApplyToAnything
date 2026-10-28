class Job {
  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.url,
    required this.source,
    required this.description,
    required this.location,
    required this.country,
    required this.remote,
    required this.salary,
    required this.tags,
    required this.postedAt,
  });

  final String id, title, company, url, source, description, location, country;
  final String salary, postedAt;
  final bool remote;
  final List<String> tags;

  factory Job.fromJson(Map<String, dynamic> j) {
    return Job(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? 'Sin título').toString(),
      company: (j['company'] ?? 'Sin empresa').toString(),
      url: (j['url'] ?? '').toString(),
      source: (j['source'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      country: (j['country'] ?? 'xx').toString(),
      remote: j['remote'] == true,
      salary: (j['salary'] ?? '').toString(),
      tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      postedAt: (j['posted_at'] ?? '').toString(),
    );
  }
}
