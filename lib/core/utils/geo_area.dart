import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

/// Geometry helpers for measuring map shapes (geofences).
///
/// All maths is done in metres / square metres; the `*Label` helpers turn
/// those numbers into short, human friendly strings for the UI.
class GeoArea {
  GeoArea._();

  /// Mean Earth radius in metres.
  static const double earthRadiusMeters = 6371008.8;

  /// Square metres in one hectare.
  static const double squareMetersPerHectare = 10000;

  static final NumberFormat _grouped = NumberFormat('#,##0.##');
  static final NumberFormat _oneDecimal = NumberFormat('#,##0.0');
  static final NumberFormat _whole = NumberFormat('#,##0');

  // ───────────────────────────── Circle ─────────────────────────────

  /// Area of a circle in square metres.
  static double circleArea(double radiusMeters) =>
      math.pi * radiusMeters * radiusMeters;

  /// Circumference of a circle in metres.
  static double circleCircumference(double radiusMeters) =>
      2 * math.pi * radiusMeters;

  // ───────────────────────────── Polygon ─────────────────────────────

  /// Area of a polygon ring in square metres.
  ///
  /// The last vertex is implicitly connected back to the first. Uses the
  /// spherical excess formula, which stays accurate for the field-sized
  /// zones this app draws.
  static double polygonArea(List<LatLng> ring) {
    if (ring.length < 3) return 0;

    double total = 0;
    for (int i = 0; i < ring.length; i++) {
      final lower = ring[(i + ring.length - 1) % ring.length];
      final middle = ring[i];
      final upper = ring[(i + 1) % ring.length];

      // Normalise the longitude delta so that rings crossing the
      // antimeridian do not produce a wild result.
      var deltaLng = _toRadians(upper.longitude) - _toRadians(lower.longitude);
      if (deltaLng > math.pi) {
        deltaLng -= 2 * math.pi;
      } else if (deltaLng < -math.pi) {
        deltaLng += 2 * math.pi;
      }

      total += deltaLng * math.sin(_toRadians(middle.latitude));
    }

    return (total * earthRadiusMeters * earthRadiusMeters / 2).abs();
  }

  /// Total boundary length of a polygon ring in metres.
  static double polygonPerimeter(List<LatLng> ring) {
    if (ring.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < ring.length; i++) {
      total += distanceMeters(ring[i], ring[(i + 1) % ring.length]);
    }
    return total;
  }

  /// Great-circle distance between two points in metres.
  static double distanceMeters(LatLng a, LatLng b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = lat2 - lat1;
    final dLng = _toRadians(b.longitude - a.longitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Centroid of a polygon ring, handy for placing area labels on a map.
  static LatLng polygonCentroid(List<LatLng> ring) {
    if (ring.isEmpty) return const LatLng(0, 0);

    final lat0 = ring.first.latitude;
    final lng0 = ring.first.longitude;

    if (ring.length < 3) {
      double latSum = 0;
      double lngSum = 0;
      for (final point in ring) {
        latSum += point.latitude;
        lngSum += point.longitude;
      }
      return LatLng(latSum / ring.length, lngSum / ring.length);
    }

    // Work in a locally scaled (equirectangular) plane.
    final cos0 = math.cos(_toRadians(lat0));
    double twiceArea = 0;
    double x = 0;
    double y = 0;

    for (int i = 0; i < ring.length; i++) {
      final p = ring[i];
      final q = ring[(i + 1) % ring.length];

      final px = (p.longitude - lng0) * cos0;
      final py = p.latitude - lat0;
      final qx = (q.longitude - lng0) * cos0;
      final qy = q.latitude - lat0;

      final cross = px * qy - qx * py;
      twiceArea += cross;
      x += (px + qx) * cross;
      y += (py + qy) * cross;
    }

    if (twiceArea.abs() < 1e-12) {
      double latSum = 0;
      double lngSum = 0;
      for (final point in ring) {
        latSum += point.latitude;
        lngSum += point.longitude;
      }
      return LatLng(latSum / ring.length, lngSum / ring.length);
    }

    x /= (3 * twiceArea);
    y /= (3 * twiceArea);

    return LatLng(lat0 + y, lng0 + (cos0 == 0 ? x : x / cos0));
  }

  // ──────────────────────────── Formatting ────────────────────────────

  /// `850 m²`, `0.45 ha`, `12.35 ha`, `1,204 ha`.
  static String areaLabel(double squareMeters) {
    if (squareMeters.isNaN || squareMeters.isInfinite || squareMeters <= 0) {
      return '0 m²';
    }

    final hectares = squareMeters / squareMetersPerHectare;
    if (hectares < 0.1) return '${_grouped.format(squareMeters)} m²';
    if (hectares < 100) return '${hectares.toStringAsFixed(2)} ha';
    if (hectares < 1000) return '${_oneDecimal.format(hectares)} ha';
    return '${_whole.format(hectares)} ha';
  }

  /// `12.35 ha (123,500 m²)` — for rows with enough room for both units.
  static String areaLabelDetailed(double squareMeters) {
    if (squareMeters.isNaN || squareMeters.isInfinite || squareMeters <= 0) {
      return '0 m²';
    }
    return '${areaLabel(squareMeters)} '
        '(${_whole.format(squareMeters)} m²)';
  }

  /// `450 m`, `1.25 km`.
  static String lengthLabel(double meters) {
    if (meters.isNaN || meters.isInfinite || meters <= 0) return '0 m';
    if (meters < 1000) return '${_whole.format(meters)} m';
    return '${_grouped.format(meters / 1000)} km';
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
