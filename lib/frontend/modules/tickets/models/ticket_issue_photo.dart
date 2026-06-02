import 'dart:io';

class TicketIssuePhoto {
  const TicketIssuePhoto({
    required this.file,
    required this.latitude,
    required this.longitude,
    required this.verifiedAt,
    this.address,
  });

  final File file;
  final double latitude;
  final double longitude;
  final DateTime verifiedAt;
  final String? address;

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
