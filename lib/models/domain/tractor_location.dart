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
    this.imei,
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
  final String? imei;

  /// Minimum speed (km/h) to consider a tractor as actually moving.
  /// Filters out GPS drift noise which commonly reports 2–10 km/h on
  /// stationary devices.
  static const double _movingThreshold = 3.0;

  /// Online but speed is below moving threshold.
  bool get isIdle => isOnline && (speed == null || speed! < _movingThreshold);

  /// Online and moving above the GPS noise threshold.
  bool get isMoving => isOnline && speed != null && speed! >= _movingThreshold;

  String get label => noPlate;
  String get subtitle => '$brand $model';

  String get statusLabel => isMoving
      ? 'Moving'
      : isIdle
          ? 'Idle'
          : 'Offline';

  DateTime? get lastHeartbeatAt {
    final rawHeartbeatAt = heartbeatAt;
    if (rawHeartbeatAt == null || rawHeartbeatAt.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(rawHeartbeatAt);
    if (parsed == null) {
      return null;
    }

    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  String get lastOnlineLabel {
    final lastSeenAt = lastHeartbeatAt;
    if (lastSeenAt == null) {
      return 'Unavailable';
    }

    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    return '${lastSeenAt.day}/${lastSeenAt.month}/${lastSeenAt.year}';
  }

  factory TractorLocation.fromTractorJson(
    Map<String, dynamic> json, {
    bool includeDeviceLocation = true,
  }) {
    final device = json['device'] as Map<String, dynamic>?;
    final location = includeDeviceLocation
        ? (device?['location'] as Map<String, dynamic>?)
        : null;

    return TractorLocation(
      id: json['id'] as int,
      noPlate: json['no_plate']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      isOnline: includeDeviceLocation && device?['online'] == true,
      lat: _parseDouble(location?['lat']) ?? 0,
      lng: _parseDouble(location?['lng']) ?? 0,
      speed: _parseDouble(location?['speed']),
      direction: _parseDouble(location?['direction']),
      heartbeatAt: location?['heartbeat_at']?.toString(),
      deviceId: device?['id'] as int?,
      imei: json['imei']?.toString() ?? device?['imei']?.toString(),
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
