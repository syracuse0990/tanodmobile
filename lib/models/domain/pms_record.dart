class PmsChecklistItem {
  const PmsChecklistItem({
    required this.name,
    this.done = false,
    this.notes,
  });

  final String name;
  final bool done;
  final String? notes;

  factory PmsChecklistItem.fromJson(Map<String, dynamic> json) {
    return PmsChecklistItem(
      name: json['name']?.toString() ?? '',
      done: json['done'] == true,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'done': done,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  PmsChecklistItem copyWith({bool? done, String? notes}) {
    return PmsChecklistItem(
      name: name,
      done: done ?? this.done,
      notes: notes ?? this.notes,
    );
  }
}

class PmsRecord {
  const PmsRecord({
    required this.id,
    required this.tractorId,
    this.tractor,
    this.maintenanceDate,
    this.hoursAtMaintenance = 0,
    this.kmAtMaintenance = 0,
    this.checklist = const [],
    this.description,
    this.conclusion,
    this.requestNotes,
    this.status = 'scheduled',
    this.performer,
    this.creator,
    this.requester,
    this.images = const [],
    this.createdAt,
  });

  final int id;
  final int tractorId;
  final PmsTractorInfo? tractor;
  final String? maintenanceDate;
  final double hoursAtMaintenance;
  final double kmAtMaintenance;
  final List<PmsChecklistItem> checklist;
  final String? description;
  final String? conclusion;
  final String? requestNotes;
  final String status;
  final PmsUserInfo? performer;
  final PmsUserInfo? creator;
  final PmsUserInfo? requester;
  final List<PmsImage> images;
  final String? createdAt;

  bool get isCompleted => status == 'completed';
  bool get isScheduled => status == 'scheduled';

  factory PmsRecord.fromJson(Map<String, dynamic> json) {
    final checklistRaw = json['pms_checklist'] as List<dynamic>? ?? [];
    final imagesRaw = json['images'] as List<dynamic>? ?? [];

    return PmsRecord(
      id: json['id'] as int,
      tractorId: json['tractor_id'] as int,
      tractor: json['tractor'] != null
          ? PmsTractorInfo.fromJson(json['tractor'] as Map<String, dynamic>)
          : null,
      maintenanceDate: json['maintenance_date']?.toString(),
      hoursAtMaintenance: _parseDouble(json['hours_at_maintenance']),
      kmAtMaintenance: _parseDouble(json['km_at_maintenance']),
      checklist: checklistRaw
          .whereType<Map<String, dynamic>>()
          .map(PmsChecklistItem.fromJson)
          .toList(growable: false),
      description: json['description']?.toString(),
      conclusion: json['conclusion']?.toString(),
      requestNotes: json['request_notes']?.toString(),
      status: json['status']?.toString() ?? 'scheduled',
      performer: json['performer'] != null
          ? PmsUserInfo.fromJson(json['performer'] as Map<String, dynamic>)
          : null,
      creator: json['creator'] != null
          ? PmsUserInfo.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
      requester: json['requester'] != null
          ? PmsUserInfo.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      images: imagesRaw
          .whereType<Map<String, dynamic>>()
          .map(PmsImage.fromJson)
          .toList(growable: false),
      createdAt: json['created_at']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class PmsTractorInfo {
  const PmsTractorInfo({required this.id, this.noPlate, this.brand, this.model});

  final int id;
  final String? noPlate;
  final String? brand;
  final String? model;

  String get label {
    if (noPlate != null && noPlate!.isNotEmpty) return noPlate!;
    final parts = [brand, model].where((s) => s != null && s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Tractor #$id';
  }

  factory PmsTractorInfo.fromJson(Map<String, dynamic> json) {
    return PmsTractorInfo(
      id: json['id'] as int,
      noPlate: json['no_plate']?.toString(),
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
    );
  }
}

class PmsUserInfo {
  const PmsUserInfo({required this.id, this.name});

  final int id;
  final String? name;

  factory PmsUserInfo.fromJson(Map<String, dynamic> json) {
    return PmsUserInfo(
      id: json['id'] as int,
      name: json['name']?.toString(),
    );
  }
}

class PmsImage {
  const PmsImage({required this.id, required this.url, this.type});

  final int id;
  final String url;
  final String? type;

  factory PmsImage.fromJson(Map<String, dynamic> json) {
    return PmsImage(
      id: json['id'] as int,
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString(),
    );
  }
}
