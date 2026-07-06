class TractorPart {
  const TractorPart({
    required this.id,
    required this.name,
    this.amount,
  });

  final int id;
  final String name;
  final double? amount;

  factory TractorPart.fromJson(Map<String, dynamic> json) {
    return TractorPart(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] != null) ? double.tryParse(json['amount'].toString()) : null,
    );
  }
}
