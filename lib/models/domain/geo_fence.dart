/// Domain model for a geofence from the API.
class GeoFenceDevice {
  const GeoFenceDevice({
    required this.id,
    this.imei,
    this.deviceName,
    this.tractor,
  });

  final int id;
  final String? imei;
  final String? deviceName;
  final GeoFenceTractorInfo? tractor;

  factory GeoFenceDevice.fromJson(Map<String, dynamic> json) {
    return GeoFenceDevice(
      id: json['id'] as int,
      imei: json['imei']?.toString(),
      deviceName: json['device_name']?.toString(),
      tractor: json['tractor'] != null
          ? GeoFenceTractorInfo.fromJson(
              json['tractor'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GeoFenceTractorInfo {
  const GeoFenceTractorInfo({
    required this.id,
    this.noPlate,
    this.brand,
    this.model,
  });

  final int id;
  final String? noPlate;
  final String? brand;
  final String? model;

  String get label {
    if (noPlate != null && noPlate!.isNotEmpty) return noPlate!;
    final parts = [brand, model].where((s) => s != null && s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Tractor #$id';
  }

  factory GeoFenceTractorInfo.fromJson(Map<String, dynamic> json) {
    return GeoFenceTractorInfo(
      id: json['id'] as int,
      noPlate: json['no_plate']?.toString(),
      brand: json['brand']?.toString(),
      model: json['model']?.toString(),
    );
  }
}

class GeoFence {
  const GeoFence({
    required this.id,
    required this.name,
    required this.shape,
    this.centerLat,
    this.centerLng,
    this.radius,
    this.coordinates,
    required this.alertOn,
    this.isActive = true,
    this.devices = const [],
    this.createdAt,
  });

  final int id;
  final String name;
  final String shape; // 'circle' or 'polygon'
  final double? centerLat;
  final double? centerLng;
  final double? radius;
  final List<GeoFenceCoordinate>? coordinates;
  final String alertOn; // 'enter', 'exit', 'both'
  final bool isActive;
  final List<GeoFenceDevice> devices;
  final String? createdAt;

  bool get isCircle => shape == 'circle';
  bool get isPolygon => shape == 'polygon';

  String get alertOnLabel {
    switch (alertOn) {
      case 'enter':
        return 'Enter';
      case 'exit':
        return 'Exit';
      case 'both':
        return 'Enter & Exit';
      default:
        return alertOn;
    }
  }

  factory GeoFence.fromJson(Map<String, dynamic> json) {
    final devicesRaw = json['devices'] as List<dynamic>? ?? [];
    final coordsRaw = json['coordinates'] as List<dynamic>?;

    return GeoFence(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      shape: json['shape']?.toString() ?? 'circle',
      centerLat: _parseDouble(json['center_lat']),
      centerLng: _parseDouble(json['center_lng']),
      radius: _parseDouble(json['radius']),
      coordinates: coordsRaw
          ?.whereType<Map<String, dynamic>>()
          .map(GeoFenceCoordinate.fromJson)
          .toList(growable: false),
      alertOn: json['alert_on']?.toString() ?? 'both',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      devices: devicesRaw
          .whereType<Map<String, dynamic>>()
          .map(GeoFenceDevice.fromJson)
          .toList(growable: false),
      createdAt: json['created_at']?.toString(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class GeoFenceCoordinate {
  const GeoFenceCoordinate({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory GeoFenceCoordinate.fromJson(Map<String, dynamic> json) {
    return GeoFenceCoordinate(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}
