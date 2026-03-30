/// Domain model for a tractor booking from the API.
class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.bookingDate,
    this.startDate,
    this.endDate,
    this.purpose,
    this.farmAreaHectares,
    this.notes,
    this.startTime,
    this.endTime,
    this.tractorId,
    this.tractorLabel,
    this.tractorBrand,
    this.tractorModel,
    this.bookedByName,
    this.approvedByName,
    this.farmerId,
    this.farmerName,
    this.createdAt,
  });

  final int id;
  final String status;
  final DateTime bookingDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? purpose;
  final double? farmAreaHectares;
  final String? notes;
  final String? startTime;
  final String? endTime;
  final int? tractorId;
  final String? tractorLabel;
  final String? tractorBrand;
  final String? tractorModel;
  final String? bookedByName;
  final String? approvedByName;
  final int? farmerId;
  final String? farmerName;
  final DateTime? createdAt;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isUpcoming => status == 'pending' || status == 'approved';
  bool get isDone => status == 'completed' || status == 'cancelled' || status == 'rejected';
  bool get isCancellable => status == 'pending' || status == 'approved';
  bool get isApprovable => status == 'pending';
  bool get isEditable => status == 'pending' || status == 'approved';

  /// Human-readable date like "Mar 30, 2026" or range "Mar 30 - Apr 2, 2026".
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String fmt(DateTime d) =>
        '${months[d.month - 1]} ${d.day}, ${d.year}';
    if (startDate != null && endDate != null && startDate != endDate) {
      return '${fmt(startDate!)} – ${fmt(endDate!)}';
    }
    return fmt(startDate ?? bookingDate);
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final tractor = json['tractor'] as Map<String, dynamic>?;
    final bookedBy = json['booked_by'] as Map<String, dynamic>?;
    final approvedBy = json['approved_by'] as Map<String, dynamic>?;
    final farmer = json['farmer'] as Map<String, dynamic>?;

    return Booking(
      id: json['id'] as int,
      status: json['status']?.toString() ?? 'pending',
      bookingDate: DateTime.tryParse(json['booking_date']?.toString() ?? '') ?? DateTime.now(),
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? ''),
      purpose: json['purpose']?.toString(),
      farmAreaHectares: _parseDouble(json['farm_area_hectares']),
      notes: json['notes']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      tractorId: tractor?['id'] as int?,
      tractorLabel: tractor?['no_plate']?.toString(),
      tractorBrand: tractor?['brand']?.toString(),
      tractorModel: tractor?['model']?.toString(),
      bookedByName: bookedBy?['name']?.toString(),
      approvedByName: approvedBy?['name']?.toString(),
      farmerId: farmer?['id'] as int?,
      farmerName: farmer?['name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
