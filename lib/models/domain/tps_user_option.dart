class TpsUserOption {
  const TpsUserOption({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory TpsUserOption.fromJson(Map<String, dynamic> json) {
    return TpsUserOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
    );
  }

  final int id;
  final String name;
  final String? email;
  final String? phone;

  String get subtitle {
    return [email, phone]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' • ');
  }

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return name.toLowerCase().contains(normalizedQuery) ||
        (email?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (phone?.toLowerCase().contains(normalizedQuery) ?? false);
  }
}