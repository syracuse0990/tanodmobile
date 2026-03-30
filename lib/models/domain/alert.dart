/// Domain model for a tractor alert from the API.
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isAcknowledged,
    required this.createdAt,
    this.tractorId,
    this.tractorLabel,
    this.deviceId,
    this.meta,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final bool isAcknowledged;
  final DateTime createdAt;
  final int? tractorId;
  final String? tractorLabel;
  final int? deviceId;
  final Map<String, dynamic>? meta;

  /// Human-readable relative time.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    final tractor = json['tractor'] as Map<String, dynamic>?;

    return Alert(
      id: json['id'] as int,
      type: json['type']?.toString() ?? 'custom',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isAcknowledged: json['is_acknowledged'] == true || json['is_acknowledged'] == 1,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      tractorId: json['tractor_id'] as int?,
      tractorLabel: tractor?['no_plate']?.toString(),
      deviceId: json['device_id'] as int?,
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : null,
    );
  }
}
