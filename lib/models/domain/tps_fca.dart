class TpsFca {
  static const int totalDataCheckpoints = 4;

  const TpsFca({
    required this.id,
    required this.name,
    this.organizationName,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.province,
    this.cityTown,
    this.barangay,
    this.dateReceived,
    this.parkingLatitude,
    this.parkingLongitude,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? organizationName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? province;
  final String? cityTown;
  final String? barangay;
  final DateTime? dateReceived;
  final double? parkingLatitude;
  final double? parkingLongitude;
  final DateTime? createdAt;

  String get fullName {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    return name;
  }

  String get locationLabel {
    return [barangay, cityTown, province]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  String get contactLabel {
    return [phone, email]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' • ');
  }

  bool get hasOrganizationDetails =>
      organizationName?.trim().isNotEmpty == true;

  bool get hasContactDetails => contactLabel.isNotEmpty;

  bool get hasLocationDetails {
    return locationLabel.isNotEmpty ||
        (parkingLatitude != null && parkingLongitude != null);
  }

  bool get hasReceivedDetails => dateReceived != null;

  int get completedDataCheckpoints {
    return [
      hasOrganizationDetails,
      hasContactDetails,
      hasLocationDetails,
      hasReceivedDetails,
    ].where((value) => value).length;
  }

  double get dataCompletionRatio =>
      completedDataCheckpoints / totalDataCheckpoints;

  bool get isCompletedData =>
      completedDataCheckpoints == totalDataCheckpoints;

  String get dataStatusLabel =>
      isCompletedData ? 'Completed' : 'Draft';

  factory TpsFca.fromJson(Map<String, dynamic> json) {
    final parkingLocation = json['parking_location'] as Map<String, dynamic>?;

    double? toDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value?.toString() ?? '');
    }

    return TpsFca(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      organizationName: json['organization_name']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      province: json['province']?.toString(),
      cityTown: json['city_town']?.toString(),
      barangay: json['barangay']?.toString(),
      dateReceived: DateTime.tryParse(json['date_received']?.toString() ?? ''),
      parkingLatitude: toDouble(parkingLocation?['latitude']),
      parkingLongitude: toDouble(parkingLocation?['longitude']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}