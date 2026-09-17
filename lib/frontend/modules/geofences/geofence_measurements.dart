import 'package:latlong2/latlong.dart';
import 'package:tanodmobile/core/utils/geo_area.dart';
import 'package:tanodmobile/models/domain/geo_fence.dart';

/// Measurement helpers for saved geofences.
///
/// Works for both shapes: circles are measured from their radius, polygons
/// from their stored vertices.
extension GeoFenceMeasurements on GeoFence {
  /// Polygon vertices as map points (empty for circle geofences).
  List<LatLng> get ring =>
      coordinates
          ?.map((coordinate) => LatLng(coordinate.lat, coordinate.lng))
          .toList(growable: false) ??
      const <LatLng>[];

  /// Area covered by the geofence in square metres.
  ///
  /// Returns `null` when the stored shape data is incomplete (e.g. a
  /// polygon with fewer than three saved points).
  double? get areaSquareMeters {
    final radiusMeters = radius;
    if (isCircle && radiusMeters != null && radiusMeters > 0) {
      return GeoArea.circleArea(radiusMeters);
    }
    if (isPolygon && ring.length >= 3) {
      return GeoArea.polygonArea(ring);
    }
    return null;
  }

  /// Perimeter (polygon) or circumference (circle) in metres.
  double? get boundaryMeters {
    final radiusMeters = radius;
    if (isCircle && radiusMeters != null && radiusMeters > 0) {
      return GeoArea.circleCircumference(radiusMeters);
    }
    if (isPolygon && ring.length >= 2) {
      return GeoArea.polygonPerimeter(ring);
    }
    return null;
  }

  /// Short area label such as `12.35 ha`, or `null` when not measurable.
  String? get areaLabel {
    final area = areaSquareMeters;
    return area == null ? null : GeoArea.areaLabel(area);
  }

  /// Short boundary label such as `1.25 km`, or `null` when not measurable.
  String? get boundaryLabel {
    final boundary = boundaryMeters;
    return boundary == null ? null : GeoArea.lengthLabel(boundary);
  }
}
