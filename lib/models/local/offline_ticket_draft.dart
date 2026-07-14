import 'dart:convert';

class OfflineTicketDraft {
  final String id;
  final String subject;
  final String? category;
  final String? description;
  final int? tractorId;
  final String? tractorLabel;
  final String? fcaName;
  final DateTime? dateOfFailure;
  final String? actionTaken;
  final String? nameplatePhotoPath;
  final String? dashboardPhotoPath;
  final List<String> damagePhotoPaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final Map<String, dynamic> payload;

  OfflineTicketDraft({
    required this.id,
    required this.subject,
    this.category,
    this.description,
    this.tractorId,
    this.tractorLabel,
    this.fcaName,
    this.dateOfFailure,
    this.actionTaken,
    this.nameplatePhotoPath,
    this.dashboardPhotoPath,
    this.damagePhotoPaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
    required this.payload,
  });

  OfflineTicketDraft copyWith({
    String? id,
    String? subject,
    String? category,
    String? description,
    int? tractorId,
    String? tractorLabel,
    String? fcaName,
    DateTime? dateOfFailure,
    String? actionTaken,
    String? nameplatePhotoPath,
    String? dashboardPhotoPath,
    List<String>? damagePhotoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    Map<String, dynamic>? payload,
  }) {
    return OfflineTicketDraft(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      description: description ?? this.description,
      tractorId: tractorId ?? this.tractorId,
      tractorLabel: tractorLabel ?? this.tractorLabel,
      fcaName: fcaName ?? this.fcaName,
      dateOfFailure: dateOfFailure ?? this.dateOfFailure,
      actionTaken: actionTaken ?? this.actionTaken,
      nameplatePhotoPath: nameplatePhotoPath ?? this.nameplatePhotoPath,
      dashboardPhotoPath: dashboardPhotoPath ?? this.dashboardPhotoPath,
      damagePhotoPaths: damagePhotoPaths ?? this.damagePhotoPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'category': category,
        'description': description,
        'tractor_id': tractorId,
        'tractor_label': tractorLabel,
        'fca_name': fcaName,
        'date_of_failure': dateOfFailure?.toIso8601String(),
        'action_taken': actionTaken,
        'nameplate_photo_path': nameplatePhotoPath,
        'dashboard_photo_path': dashboardPhotoPath,
        'damage_photo_paths': damagePhotoPaths,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'synced': synced,
        'payload': payload,
      };

  factory OfflineTicketDraft.fromJson(Map<String, dynamic> json) =>
      OfflineTicketDraft(
        id: json['id'] as String,
        subject: json['subject'] as String,
        category: json['category'] as String?,
        description: json['description'] as String?,
        tractorId: json['tractor_id'] as int?,
        tractorLabel: json['tractor_label'] as String?,
        fcaName: json['fca_name'] as String?,
        dateOfFailure: json['date_of_failure'] != null
            ? DateTime.parse(json['date_of_failure'] as String)
            : null,
        actionTaken: json['action_taken'] as String?,
        nameplatePhotoPath: json['nameplate_photo_path'] as String?,
        dashboardPhotoPath: json['dashboard_photo_path'] as String?,
        damagePhotoPaths: json['damage_photo_paths'] is List
            ? List<String>.from(json['damage_photo_paths'] as List)
            : [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        synced: json['synced'] as bool? ?? false,
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : {},
      );

  static List<OfflineTicketDraft> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>? ?? [];
    return list
        .map((e) => OfflineTicketDraft.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static String listToJson(List<OfflineTicketDraft> drafts) =>
      jsonEncode(drafts.map((d) => d.toJson()).toList(growable: false));
}
