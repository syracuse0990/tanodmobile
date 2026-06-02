import 'dart:convert';

class OfflineFcaDraft {
  const OfflineFcaDraft({
    required this.id,
    required this.organizationName,
    required this.contactName,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.provinceCode,
    this.province,
    this.cityMunicipalityCode,
    this.cityTown,
    this.barangayCode,
    this.barangay,
    this.dateReceived,
    this.notes,
    this.payload = const <String, dynamic>{},
  });

  final String id;
  final String organizationName;
  final String contactName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? phone;
  final String? email;
  final String? provinceCode;
  final String? province;
  final String? cityMunicipalityCode;
  final String? cityTown;
  final String? barangayCode;
  final String? barangay;
  final DateTime? dateReceived;
  final String? notes;
  final Map<String, dynamic> payload;

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

  Map<String, dynamic> get editableSnapshot {
    if (payload.isNotEmpty) {
      return _clonePayload(payload);
    }

    final legacyContact = _splitLegacyContactName(contactName);

    return {
      'organization_name': organizationName,
      'first_name': legacyContact.firstName,
      'last_name': legacyContact.lastName,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'province_code': provinceCode,
      'province_name': province,
      'city_municipality_code': cityMunicipalityCode,
      'city_name': cityTown,
      'barangay_code': barangayCode,
      'barangay_name': barangay,
      'date_received': dateReceived?.toIso8601String().split('T').first,
      'notes': notes,
    };
  }

  factory OfflineFcaDraft.fromSnapshot({
    required String id,
    required Map<String, dynamic> snapshot,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? notes,
  }) {
    final payload = _clonePayload(snapshot);
    final firstName = _stringValue(payload['first_name']);
    final lastName = _stringValue(payload['last_name']);

    return OfflineFcaDraft(
      id: id,
      organizationName: _stringValue(payload['organization_name']) ?? '',
      contactName:
          _stringValue(payload['contact_name']) ??
          _joinContactName(firstName, lastName),
      createdAt: createdAt,
      updatedAt: updatedAt,
      phone: _stringValue(payload['phone']),
      email: _stringValue(payload['email']),
      provinceCode: _stringValue(payload['province_code']),
      province:
          _stringValue(payload['province_name']) ??
          _stringValue(payload['province']),
      cityMunicipalityCode: _stringValue(payload['city_municipality_code']),
      cityTown:
          _stringValue(payload['city_name']) ??
          _stringValue(payload['city_town']),
      barangayCode: _stringValue(payload['barangay_code']),
      barangay:
          _stringValue(payload['barangay_name']) ??
          _stringValue(payload['barangay']),
      dateReceived: DateTime.tryParse(
        _stringValue(payload['date_received']) ?? '',
      ),
      notes: notes ?? _stringValue(payload['notes']),
      payload: payload,
    );
  }

  factory OfflineFcaDraft.fromJson(Map<String, dynamic> json) {
    final payload = _normalizedPayload(json['payload']);

    return OfflineFcaDraft(
      id: json['id']?.toString() ?? '',
      organizationName:
          _stringValue(json['organization_name']) ??
          _stringValue(payload['organization_name']) ??
          '',
      contactName:
          _stringValue(json['contact_name']) ??
          _stringValue(payload['contact_name']) ??
          _joinContactName(
            _stringValue(payload['first_name']),
            _stringValue(payload['last_name']),
          ),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      phone: _stringValue(json['phone']) ?? _stringValue(payload['phone']),
      email: _stringValue(json['email']) ?? _stringValue(payload['email']),
      provinceCode:
          _stringValue(json['province_code']) ??
          _stringValue(payload['province_code']),
      province:
          _stringValue(json['province']) ??
          _stringValue(payload['province_name']) ??
          _stringValue(payload['province']),
      cityMunicipalityCode:
          _stringValue(json['city_municipality_code']) ??
          _stringValue(payload['city_municipality_code']),
      cityTown:
          _stringValue(json['city_town']) ??
          _stringValue(payload['city_name']) ??
          _stringValue(payload['city_town']),
      barangayCode:
          _stringValue(json['barangay_code']) ??
          _stringValue(payload['barangay_code']),
      barangay:
          _stringValue(json['barangay']) ??
          _stringValue(payload['barangay_name']) ??
          _stringValue(payload['barangay']),
      dateReceived: DateTime.tryParse(
        _stringValue(json['date_received']) ??
            _stringValue(payload['date_received']) ??
            '',
      ),
      notes: _stringValue(json['notes']) ?? _stringValue(payload['notes']),
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_name': organizationName,
      'contact_name': contactName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'phone': phone,
      'email': email,
      'province_code': provinceCode,
      'province': province,
      'city_municipality_code': cityMunicipalityCode,
      'city_town': cityTown,
      'barangay_code': barangayCode,
      'barangay': barangay,
      'date_received': dateReceived?.toIso8601String(),
      'notes': notes,
      'payload': payload,
    };
  }

  OfflineFcaDraft copyWith({
    String? id,
    String? organizationName,
    String? contactName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? phone,
    String? email,
    String? provinceCode,
    String? province,
    String? cityMunicipalityCode,
    String? cityTown,
    String? barangayCode,
    String? barangay,
    DateTime? dateReceived,
    String? notes,
    Map<String, dynamic>? payload,
  }) {
    return OfflineFcaDraft(
      id: id ?? this.id,
      organizationName: organizationName ?? this.organizationName,
      contactName: contactName ?? this.contactName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      provinceCode: provinceCode ?? this.provinceCode,
      province: province ?? this.province,
      cityMunicipalityCode: cityMunicipalityCode ?? this.cityMunicipalityCode,
      cityTown: cityTown ?? this.cityTown,
      barangayCode: barangayCode ?? this.barangayCode,
      barangay: barangay ?? this.barangay,
      dateReceived: dateReceived ?? this.dateReceived,
      notes: notes ?? this.notes,
      payload: payload ?? this.payload,
    );
  }

  static Map<String, dynamic> _normalizedPayload(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _clonePayload(value);
    }

    if (value is Map) {
      return _clonePayload(Map<String, dynamic>.from(value));
    }

    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _clonePayload(Map<String, dynamic> value) {
    if (value.isEmpty) {
      return const <String, dynamic>{};
    }

    final cloned = jsonDecode(jsonEncode(value));
    if (cloned is Map<String, dynamic>) {
      return cloned;
    }

    if (cloned is Map) {
      return Map<String, dynamic>.from(cloned);
    }

    return Map<String, dynamic>.from(value);
  }

  static String? _stringValue(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static String _joinContactName(String? firstName, String? lastName) {
    return [firstName, lastName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  static ({String firstName, String lastName}) _splitLegacyContactName(
    String value,
  ) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return (firstName: '', lastName: '');
    }

    if (parts.length == 1) {
      return (firstName: parts.first, lastName: '');
    }

    return (
      firstName: parts.sublist(0, parts.length - 1).join(' '),
      lastName: parts.last,
    );
  }
}
