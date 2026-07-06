/// Domain model for a support ticket from the API.
class Ticket {
  const Ticket({
    required this.id,
    required this.subject,
    required this.status,
    this.isPartial = false,
    required this.priority,
    this.description,
    this.category,
    this.photoUrl,
    this.nameplatePhotoUrl,
    this.dashboardPhotoUrl,
    this.damagePhotos,
    this.pmsChecklist,
    this.actionTaken,
    this.serviceCharge,
    this.downPayment,
    this.installments,
    this.tractorId,
    this.tractorLabel,
    this.tractorBrand,
    this.tractorModel,
    this.submittedById,
    this.submittedByName,
    this.resolutionNotes,
    this.resolutionPhotoUrl,
    this.drPhotoUrls,
    this.resolvedById,
    this.resolvedByName,
    this.resolvedAt,
    this.assignees,
    this.comments,
    this.lastComment,
    this.lastActivityAt,
    this.createdAt,
    this.tractorParts,
  });

  final int id;
  final String subject;
  final String status;
  final bool isPartial;
  final String priority;
  final String? description;
  final String? category;
  final String? photoUrl;
  final String? nameplatePhotoUrl;
  final String? dashboardPhotoUrl;
  final List<TicketDamagePhoto>? damagePhotos;
  final List<Map<String, dynamic>>? pmsChecklist;
  final String? actionTaken;
  final double? serviceCharge;
  final double? downPayment;
  final int? installments;
  final int? tractorId;
  final String? tractorLabel;
  final String? tractorBrand;
  final String? tractorModel;
  final int? submittedById;
  final String? submittedByName;
  final String? resolutionNotes;
  final String? resolutionPhotoUrl;
  final List<String>? drPhotoUrls;
  final int? resolvedById;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final List<TicketAssignee>? assignees;
  final List<TicketComment>? comments;
  final TicketComment? lastComment;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final List<TicketTractorPart>? tractorParts;

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

  DateTime? get activityAt =>
      lastActivityAt ?? lastComment?.createdAt ?? createdAt;

  String get chatPreview {
    final latestBody = lastComment?.body.trim();
    if (latestBody != null && latestBody.isNotEmpty) {
      return latestBody;
    }

    if (lastComment?.attachmentUrl != null &&
        lastComment!.attachmentUrl!.isNotEmpty) {
      return 'Sent an attachment';
    }

    final ticketDescription = description?.trim();
    if (ticketDescription != null && ticketDescription.isNotEmpty) {
      return ticketDescription;
    }

    return 'Open the room to continue the discussion.';
  }

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
    Map<String, dynamic>? normalizeMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }

      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }

      return null;
    }

    final tractor = json['tractor'] as Map<String, dynamic>?;
    final submitter =
        normalizeMap(json['submitted_by']) ?? normalizeMap(json['submitter']);
    final resolver =
        normalizeMap(json['resolved_by']) ?? normalizeMap(json['resolver']);
    final rawAssignees = json['assignees'] as List<dynamic>?;
    final rawComments = json['comments'] as List<dynamic>?;
    final lastComment = normalizeMap(json['last_comment']);

    return Ticket(
      id: json['id'] as int,
      subject: json['subject']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      isPartial: json['is_partial'] == true,
      priority: json['priority']?.toString() ?? 'medium',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      nameplatePhotoUrl: json['nameplate_photo_url']?.toString(),
      dashboardPhotoUrl: json['dashboard_photo_url']?.toString(),
      damagePhotos: json['damage_photos'] is List
          ? (json['damage_photos'] as List)
              .map((dp) => TicketDamagePhoto.fromJson(dp as Map<String, dynamic>))
              .toList()
          : null,
      pmsChecklist: json['pms_checklist'] is List
          ? (json['pms_checklist'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : null,
      actionTaken: json['action_taken']?.toString(),
      serviceCharge: (json['service_charge'] != null)
          ? double.tryParse(json['service_charge'].toString())
          : null,
      downPayment: (json['down_payment'] != null)
          ? double.tryParse(json['down_payment'].toString())
          : null,
      installments: (json['installments'] as num?)?.toInt(),
      tractorId: tractor?['id'] as int?,
      tractorLabel: tractor?['no_plate']?.toString(),
      tractorBrand: tractor?['brand']?.toString(),
      tractorModel: tractor?['model']?.toString(),
      submittedById: submitter?['id'] as int?,
      submittedByName: submitter?['name']?.toString(),
      resolutionNotes: json['resolution_notes']?.toString(),
      resolutionPhotoUrl: json['resolution_photo_url']?.toString(),
      drPhotoUrls: (json['dr_photo_urls'] as List?)?.map((e) => e.toString()).toList(),
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
      lastComment: lastComment != null
          ? TicketComment.fromJson(lastComment)
          : null,
      lastActivityAt: DateTime.tryParse(
        json['last_activity_at']?.toString() ?? '',
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      tractorParts: json['tractor_parts'] is List
          ? (json['tractor_parts'] as List)
              .map((p) => TicketTractorPart.fromJson(p as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Ticket copyWithNewComment(TicketComment comment) {
    return Ticket(
      id: id,
      subject: subject,
      status: status,
      isPartial: isPartial,
      priority: priority,
      description: description,
      category: category,
      photoUrl: photoUrl,
      nameplatePhotoUrl: nameplatePhotoUrl,
      dashboardPhotoUrl: dashboardPhotoUrl,
      damagePhotos: damagePhotos,
      pmsChecklist: pmsChecklist,
      actionTaken: actionTaken,
      serviceCharge: serviceCharge,
      downPayment: downPayment,
      installments: installments,
      tractorId: tractorId,
      tractorLabel: tractorLabel,
      tractorBrand: tractorBrand,
      tractorModel: tractorModel,
      submittedById: submittedById,
      submittedByName: submittedByName,
      resolutionNotes: resolutionNotes,
      resolutionPhotoUrl: resolutionPhotoUrl,
      drPhotoUrls: drPhotoUrls,
      resolvedById: resolvedById,
      resolvedByName: resolvedByName,
      resolvedAt: resolvedAt,
      assignees: assignees,
      comments: [...(comments ?? []), comment],
      lastComment: comment,
      lastActivityAt: comment.createdAt ?? DateTime.now(),
      createdAt: createdAt,
      tractorParts: tractorParts,
    );
  }
}

class TicketTractorPart {
  const TicketTractorPart({
    required this.id,
    required this.name,
    required this.amount,
    this.quantity = 1,
  });

  final int id;
  final String name;
  final double amount;
  final int quantity;

  factory TicketTractorPart.fromJson(Map<String, dynamic> json) {
    return TicketTractorPart(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] != null)
          ? double.tryParse(json['amount'].toString()) ?? 0
          : 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
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

class TicketDamagePhoto {
  const TicketDamagePhoto({
    required this.id,
    required this.photoUrl,
    required this.sortOrder,
  });

  final int id;
  final String photoUrl;
  final int sortOrder;

  factory TicketDamagePhoto.fromJson(Map<String, dynamic> json) {
    return TicketDamagePhoto(
      id: json['id'] as int,
      photoUrl: json['photo_url']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
