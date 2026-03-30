/// Domain model for farmer feedback from the API.
class FarmerFeedbackItem {
  const FarmerFeedbackItem({
    required this.id,
    this.rating,
    this.feedback,
    this.category,
    this.status,
    this.conclusion,
    this.adminResponse,
    this.tractorLabel,
    this.submitterName,
    this.bookingPurpose,
    this.bookingDate,
    this.createdAt,
  });

  final int id;
  final int? rating;
  final String? feedback;
  final String? category;
  final String? status;
  final String? conclusion;
  final String? adminResponse;
  final String? tractorLabel;
  final String? submitterName;
  final String? bookingPurpose;
  final String? bookingDate;
  final DateTime? createdAt;

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  factory FarmerFeedbackItem.fromJson(Map<String, dynamic> json) {
    final tractor = json['tractor'] as Map<String, dynamic>?;
    final submitter = json['submitter'] as Map<String, dynamic>?;
    final booking = json['booking'] as Map<String, dynamic>?;

    return FarmerFeedbackItem(
      id: json['id'] as int,
      rating: json['rating'] as int?,
      feedback: json['feedback']?.toString(),
      category: json['category']?.toString(),
      status: json['status']?.toString(),
      conclusion: json['conclusion']?.toString(),
      adminResponse: json['admin_response']?.toString(),
      tractorLabel: tractor?['no_plate']?.toString(),
      submitterName: submitter?['name']?.toString(),
      bookingPurpose: booking?['purpose']?.toString(),
      bookingDate: booking?['booking_date']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
