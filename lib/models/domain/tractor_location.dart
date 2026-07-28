enum TractorLiveStatus {
  moving,
  idling,
  parked,
  offline;

  static TractorLiveStatus? fromApi(dynamic value) {
    return switch (value?.toString().toLowerCase()) {
      'moving' => TractorLiveStatus.moving,
      'idling' => TractorLiveStatus.idling,
      'parked' => TractorLiveStatus.parked,
      'offline' => TractorLiveStatus.offline,
      _ => null,
    };
  }
}

/// Represents a tractor with its device GPS location for the map.
class TractorLocation {
  const TractorLocation({
    required this.id,
    required this.noPlate,
    required this.brand,
    required this.model,
    required bool isOnline,
    required this.lat,
    required this.lng,
    this.speed,
    this.direction,
    this.heartbeatAt,
    this.gpsTime,
    this.gpsMinutesAgo,
    this.liveStatus,
    this.accStatus,
    this.deviceId,
    this.imei,
  }) : _legacyIsOnline = isOnline;

  final int id;
  final String noPlate;
  final String brand;
  final String model;
  final bool _legacyIsOnline;
  final double lat;
  final double lng;
  final double? speed;
  final double? direction;
  final String? heartbeatAt;
  final String? gpsTime;
  final int? gpsMinutesAgo;
  final TractorLiveStatus? liveStatus;
  final bool? accStatus;
  final int? deviceId;
  final String? imei;

  /// Minimum speed (km/h) to consider a tractor as actually moving.
  /// Filters out GPS drift noise which commonly reports 2–10 km/h on
  /// stationary devices.
  static const double _movingThreshold = 3.0;
  static const int _movementFreshnessMinutes = 5;

  TractorLiveStatus get resolvedLiveStatus {
    final apiStatus = liveStatus;
    if (apiStatus != null) {
      return apiStatus;
    }

    if (!_legacyIsOnline) {
      return TractorLiveStatus.offline;
    }

    if (accStatus == false) {
      return TractorLiveStatus.parked;
    }

    final hasFreshMovement =
        speed != null &&
        speed! >= _movingThreshold &&
        (gpsMinutesAgo == null || gpsMinutesAgo! <= _movementFreshnessMinutes);

    return hasFreshMovement
        ? TractorLiveStatus.moving
        : TractorLiveStatus.idling;
  }

  bool get isOnline => resolvedLiveStatus != TractorLiveStatus.offline;

  bool get isIdling => resolvedLiveStatus == TractorLiveStatus.idling;

  bool get isParked => resolvedLiveStatus == TractorLiveStatus.parked;

  /// Backward-compatible stationary state for callers that do not yet
  /// distinguish ACC-on idling from ACC-off parked.
  bool get isIdle => isIdling || isParked;

  /// Online and moving above the GPS noise threshold.
  bool get isMoving => resolvedLiveStatus == TractorLiveStatus.moving;

  String get label => noPlate;
  String get subtitle => '$brand $model';

  String get statusLabel => switch (resolvedLiveStatus) {
    TractorLiveStatus.moving => 'Moving',
    TractorLiveStatus.idling => 'Idling',
    TractorLiveStatus.parked => 'Parked',
    TractorLiveStatus.offline => 'Offline',
  };

  DateTime? get lastHeartbeatAt {
    return _parseDateTime(heartbeatAt);
  }

  DateTime? get lastGpsFixAt {
    return _parseDateTime(gpsTime);
  }

  String get lastGpsFixLabel {
    final minutesAgo = gpsMinutesAgo;
    if (minutesAgo != null) {
      return _formatMinutesAgo(minutesAgo);
    }

    return _formatDateTimeAge(lastGpsFixAt);
  }

  static DateTime? _parseDateTime(String? rawDateTime) {
    if (rawDateTime == null || rawDateTime.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(rawDateTime);
    if (parsed == null) {
      return null;
    }

    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  String get lastOnlineLabel {
    return _formatDateTimeAge(lastHeartbeatAt);
  }

  static String _formatDateTimeAge(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unavailable';
    }

    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just now';
    }

    return _formatMinutesAgo(diff.inMinutes, fallbackDate: dateTime);
  }

  static String _formatMinutesAgo(int minutes, {DateTime? fallbackDate}) {
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';

    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';

    final days = hours ~/ 24;
    if (days < 7 || fallbackDate == null) return '${days}d ago';

    return '${fallbackDate.day}/${fallbackDate.month}/${fallbackDate.year}';
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
      gpsTime: location?['gps_time']?.toString(),
      gpsMinutesAgo: _parseInt(location?['gps_minutes_ago']),
      liveStatus: TractorLiveStatus.fromApi(location?['live_status']),
      accStatus: _parseBool(location?['acc_status']),
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

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return switch (value.toString().toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => null,
    };
  }
}
