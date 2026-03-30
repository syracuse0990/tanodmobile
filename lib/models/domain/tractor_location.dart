/// Represents a tractor with its device GPS location for the map.
class TractorLocation {
  const TractorLocation({
    required this.id,
    required this.noPlate,
    required this.brand,
    required this.model,
    required this.isOnline,
    required this.lat,
    required this.lng,
    this.speed,
    this.direction,
    this.heartbeatAt,
    this.deviceId,
  });

  final int id;
  final String noPlate;
  final String brand;
  final String model;
  final bool isOnline;
  final double lat;
  final double lng;
  final double? speed;
  final double? direction;
  final String? heartbeatAt;
  final int? deviceId;

  /// Online but speed is 0 (or null).
  bool get isIdle => isOnline && (speed == null || speed == 0);

  /// Online and moving.
  bool get isMoving => isOnline && speed != null && speed! > 0;

  String get label => noPlate;
  String get subtitle => '$brand $model';

  String get statusLabel => isMoving
      ? 'Moving'
      : isIdle
          ? 'Idle'
          : 'Offline';

  factory TractorLocation.fromTractorJson(Map<String, dynamic> json) {
    final device = json['device'] as Map<String, dynamic>?;
    final location = device?['location'] as Map<String, dynamic>?;

    return TractorLocation(
      id: json['id'] as int,
      noPlate: json['no_plate']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      isOnline: device?['online'] == true,
      lat: _parseDouble(location?['lat']) ?? 0,
      lng: _parseDouble(location?['lng']) ?? 0,
      speed: _parseDouble(location?['speed']),
      direction: _parseDouble(location?['direction']),
      heartbeatAt: location?['heartbeat_at']?.toString(),
      deviceId: device?['id'] as int?,
    );
  }

  bool get hasLocation => lat != 0 || lng != 0;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
