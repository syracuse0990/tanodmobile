/// Domain model for a support ticket from the API.
class Ticket {
  const Ticket({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    this.description,
    this.category,
    this.photoUrl,
    this.tractorId,
    this.tractorLabel,
    this.tractorBrand,
    this.tractorModel,
    this.submittedById,
    this.submittedByName,
    this.resolutionNotes,
    this.resolutionPhotoUrl,
    this.resolvedById,
    this.resolvedByName,
    this.resolvedAt,
    this.assignees,
    this.comments,
    this.createdAt,
  });

  final int id;
  final String subject;
  final String status;
  final String priority;
  final String? description;
  final String? category;
  final String? photoUrl;
  final int? tractorId;
  final String? tractorLabel;
  final String? tractorBrand;
  final String? tractorModel;
  final int? submittedById;
  final String? submittedByName;
  final String? resolutionNotes;
  final String? resolutionPhotoUrl;
  final int? resolvedById;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final List<TicketAssignee>? assignees;
  final List<TicketComment>? comments;
  final DateTime? createdAt;

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  bool get isResolvable => status == 'open' || status == 'in_progress';

  String get assigneeNames {
    if (assignees == null || assignees!.isEmpty) return 'Unassigned';
    return assignees!.map((a) => a.name).join(', ');
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final tractor = json['tractor'] as Map<String, dynamic>?;
    final submitter = json['submitted_by'] as Map<String, dynamic>?;
    final resolver = json['resolved_by'] as Map<String, dynamic>?;
    final rawAssignees = json['assignees'] as List<dynamic>?;
    final rawComments = json['comments'] as List<dynamic>?;

    return Ticket(
      id: json['id'] as int,
      subject: json['subject']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'medium',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      tractorId: tractor?['id'] as int?,
      tractorLabel: tractor?['no_plate']?.toString(),
      tractorBrand: tractor?['brand']?.toString(),
      tractorModel: tractor?['model']?.toString(),
      submittedById: submitter?['id'] as int?,
      submittedByName: submitter?['name']?.toString(),
      resolutionNotes: json['resolution_notes']?.toString(),
      resolutionPhotoUrl: json['resolution_photo_url']?.toString(),
      resolvedById: resolver?['id'] as int?,
      resolvedByName: resolver?['name']?.toString(),
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
      assignees: rawAssignees
          ?.whereType<Map<String, dynamic>>()
          .map(TicketAssignee.fromJson)
          .toList(),
      comments: rawComments
          ?.whereType<Map<String, dynamic>>()
          .map(TicketComment.fromJson)
          .toList(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Ticket copyWithNewComment(TicketComment comment) {
    return Ticket(
      id: id,
      subject: subject,
      status: status,
      priority: priority,
      description: description,
      category: category,
      photoUrl: photoUrl,
      tractorId: tractorId,
      tractorLabel: tractorLabel,
      tractorBrand: tractorBrand,
      tractorModel: tractorModel,
      submittedById: submittedById,
      submittedByName: submittedByName,
      resolutionNotes: resolutionNotes,
      resolutionPhotoUrl: resolutionPhotoUrl,
      resolvedById: resolvedById,
      resolvedByName: resolvedByName,
      resolvedAt: resolvedAt,
      assignees: assignees,
      comments: [...(comments ?? []), comment],
      createdAt: createdAt,
    );
  }
}

class TicketAssignee {
  const TicketAssignee({required this.id, required this.name});

  final int id;
  final String name;

  factory TicketAssignee.fromJson(Map<String, dynamic> json) {
    return TicketAssignee(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}

class TicketComment {
  const TicketComment({
    required this.id,
    required this.body,
    this.userId,
    this.userName,
    this.attachmentUrl,
    this.createdAt,
  });

  final int id;
  final String body;
  final int? userId;
  final String? userName;
  final String? attachmentUrl;
  final DateTime? createdAt;

  factory TicketComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return TicketComment(
      id: json['id'] as int,
      body: json['body']?.toString() ?? '',
      userId: user?['id'] as int?,
      userName: user?['name']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
