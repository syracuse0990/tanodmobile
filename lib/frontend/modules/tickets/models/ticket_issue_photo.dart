import 'dart:io';

class TicketIssuePhoto {
  const TicketIssuePhoto({
    required this.file,
    required this.latitude,
    required this.longitude,
    required this.verifiedAt,
    this.address,
    this.isVideo = false,
    this.durationSeconds,
  });

  final File file;
  final double latitude;
  final double longitude;
  final DateTime verifiedAt;
  final String? address;
  final bool isVideo;
  final int? durationSeconds;

  String get locationLabel {
    return 'Lat ${latitude.toStringAsFixed(6)} | Lng ${longitude.toStringAsFixed(6)}';
  }

  String? get addressLabel {
    final trimmed = address?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

class TicketIssuePhotoException implements Exception {
  const TicketIssuePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TicketIssuePhotoValidationResult {
  const TicketIssuePhotoValidationResult({
    required this.valid,
    required this.message,
  });

  final bool valid;
  final String message;
}
