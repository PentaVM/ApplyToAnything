class User {
  User({required this.id, required this.email, required this.name});

  final int id;
  final String email;
  final String name;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] as num?)?.toInt() ?? 0,
        email: (j['email'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}
