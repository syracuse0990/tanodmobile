/// Domain model for a support ticket from the API.
class Ticket {
  const Ticket({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    this.description,
    this.tractorId,
    this.tractorLabel,
    this.submitterName,
    this.assigneeName,
    this.createdAt,
  });

  final int id;
  final String subject;
  final String status;
  final String priority;
  final String? description;
  final int? tractorId;
  final String? tractorLabel;
  final String? submitterName;
  final String? assigneeName;
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
    final submitter = json['submitter'] as Map<String, dynamic>?;
    final assignee = json['assignee'] as Map<String, dynamic>?;

    return Ticket(
      id: json['id'] as int,
      subject: json['subject']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'medium',
      description: json['description']?.toString(),
      tractorId: tractor?['id'] as int?,
      tractorLabel: tractor?['no_plate']?.toString(),
      submitterName: submitter?['name']?.toString(),
      assigneeName: assignee?['name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
