class TractorInsightDetail {
  const TractorInsightDetail({
    required this.id,
    required this.label,
    this.brand,
    this.model,
    this.imei,
    this.totalDistance = 0,
    this.totalRunningHours = 0,
    this.pmsStatus = 'ok',
    this.fca,
  });

  final int id;
  final String label;
  final String? brand;
  final String? model;
  final String? imei;
  final double totalDistance;
  final double totalRunningHours;
  final String pmsStatus;
  final TractorContactInfo? fca;

  String get brandLabel {
    final parts = [brand, model]
        .whereType<String>()
        .where((value) => value.isNotEmpty);
    return parts.isEmpty ? 'Unavailable' : parts.join(' ');
  }

  String get pmsStatusLabel {
    return switch (pmsStatus) {
      'due' => 'PMS Due',
      'upcoming' => 'PMS Upcoming',
      'ok' => 'PMS OK',
      _ => pmsStatus,
    };
  }

  factory TractorInsightDetail.fromJson(Map<String, dynamic> json) {
    final assignee = json['assignee'] as Map<String, dynamic>?;

    return TractorInsightDetail(
      id: json['id'] as int,
      label: _stringValue(json['no_plate']) ?? 'Tractor #${json['id']}',
      brand: _stringValue(json['brand']),
      model: _stringValue(json['model']),
      imei: _stringValue(json['imei']),
      totalDistance: _parseDouble(json['total_distance']),
      totalRunningHours: _parseDouble(json['total_running_hours']),
      pmsStatus: _stringValue(json['pms_status']) ?? 'ok',
      fca: assignee == null ? null : TractorContactInfo.fromJson(assignee),
    );
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}

class TractorContactInfo {
  const TractorContactInfo({
    this.name,
    this.email,
    this.phone,
  });

  final String? name;
  final String? email;
  final String? phone;

  bool get isEmpty {
    return [name, email, phone].every(
      (value) => value == null || value.trim().isEmpty,
    );
  }

  factory TractorContactInfo.fromJson(Map<String, dynamic> json) {
    return TractorContactInfo(
      name: _stringValue(json['name']),
      email: _stringValue(json['email']),
      phone: _stringValue(json['phone']),
    );
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}