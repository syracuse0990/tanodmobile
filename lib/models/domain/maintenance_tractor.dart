class MaintenanceTractor {
  const MaintenanceTractor({
    required this.id,
    this.noPlate,
    this.brand,
    this.model,
    this.totalDistance = 0,
    this.totalRunningHours = 0,
    this.maintenanceKm,
    this.maintenanceHours,
    this.nextPmsHours,
    this.pmsStatus = 'ok',
    this.isMaintenanceDue = false,
    this.assigneeName,
    this.imageUrl,
  });

  final int id;
  final String? noPlate;
  final String? brand;
  final String? model;
  final double totalDistance;
  final double totalRunningHours;
  final double? maintenanceKm;
  final double? maintenanceHours;
  final double? nextPmsHours;
  final String pmsStatus;
  final bool isMaintenanceDue;
  final String? assigneeName;
  final String? imageUrl;

  String get label {
    if (noPlate != null && noPlate!.isNotEmpty) return noPlate!;
    final parts = [brand, model].where((s) => s != null && s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Tractor #$id';
  }

  String get brandModel {
    final parts = [brand, model].where((s) => s != null && s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : '';
  }

  double get hoursUntilNextPms {
    if (nextPmsHours == null) return double.infinity;
    return (nextPmsHours! - totalRunningHours).clamp(0, double.infinity);
  }

  bool get isPmsDue => pmsStatus == 'due';
  bool get isPmsUpcoming => pmsStatus == 'upcoming';

  factory MaintenanceTractor.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as List<dynamic>?;
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      final first = images.first as Map<String, dynamic>;
      imageUrl = first['url']?.toString();
    }

    final assignee = json['assignee'] as Map<String, dynamic>?;

    return MaintenanceTractor(
      id: json['id'] as int,
      noPlate: json['no_plate']?.toString(),
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
      totalDistance: _parseDouble(json['total_distance']),
      totalRunningHours: _parseDouble(json['total_running_hours']),
      maintenanceKm: _parseNullableDouble(json['maintenance_km']),
      maintenanceHours: _parseNullableDouble(json['maintenance_hours']),
      nextPmsHours: _parseNullableDouble(json['next_pms_hours']),
      pmsStatus: json['pms_status']?.toString() ?? 'ok',
      isMaintenanceDue: json['is_maintenance_due'] == true,
      assigneeName: assignee?['name']?.toString(),
      imageUrl: imageUrl,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
