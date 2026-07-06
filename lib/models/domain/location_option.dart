class LocationOption {
  const LocationOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationOption &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => code.hashCode ^ name.hashCode;
}