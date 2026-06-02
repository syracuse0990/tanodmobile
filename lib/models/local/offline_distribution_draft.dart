class OfflineDistributionDraft {
  const OfflineDistributionDraft({
    required this.id,
    required this.recipientName,
    required this.tractorLabel,
    required this.distributionDate,
    required this.createdAt,
    required this.updatedAt,
    this.area,
    this.notes,
  });

  final String id;
  final String recipientName;
  final String tractorLabel;
  final DateTime distributionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? area;
  final String? notes;

  factory OfflineDistributionDraft.fromJson(Map<String, dynamic> json) {
    return OfflineDistributionDraft(
      id: json['id']?.toString() ?? '',
      recipientName: json['recipient_name']?.toString() ?? '',
      tractorLabel: json['tractor_label']?.toString() ?? '',
      distributionDate:
          DateTime.tryParse(json['distribution_date']?.toString() ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      area: json['area']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_name': recipientName,
      'tractor_label': tractorLabel,
      'distribution_date': distributionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'area': area,
      'notes': notes,
    };
  }

  OfflineDistributionDraft copyWith({
    String? id,
    String? recipientName,
    String? tractorLabel,
    DateTime? distributionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? area,
    String? notes,
  }) {
    return OfflineDistributionDraft(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      tractorLabel: tractorLabel ?? this.tractorLabel,
      distributionDate: distributionDate ?? this.distributionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      area: area ?? this.area,
      notes: notes ?? this.notes,
    );
  }
}
