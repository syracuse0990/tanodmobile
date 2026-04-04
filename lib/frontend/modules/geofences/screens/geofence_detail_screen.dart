import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/geofence_provider.dart';
import 'package:tanodmobile/models/domain/geo_fence.dart';

class GeofenceDetailScreen extends StatefulWidget {
  const GeofenceDetailScreen({super.key, required this.geofenceId});

  final int geofenceId;

  @override
  State<GeofenceDetailScreen> createState() => _GeofenceDetailScreenState();
}

class _GeofenceDetailScreenState extends State<GeofenceDetailScreen> {
  final MapController _mapController = MapController();
  GeoFence? _geofence;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail = await context
        .read<GeoFenceProvider>()
        .fetchGeofenceDetail(widget.geofenceId);
    if (mounted) {
      setState(() {
        _geofence = detail;
        _loading = false;
      });
    }
  }

  LatLng get _center {
    final g = _geofence;
    if (g == null) return const LatLng(12.8797, 121.7740);

    if (g.isCircle && g.centerLat != null && g.centerLng != null) {
      return LatLng(g.centerLat!, g.centerLng!);
    }

    if (g.isPolygon && g.coordinates != null && g.coordinates!.isNotEmpty) {
      final lats = g.coordinates!.map((c) => c.lat);
      final lngs = g.coordinates!.map((c) => c.lng);
      return LatLng(
        (lats.reduce(math.min) + lats.reduce(math.max)) / 2,
        (lngs.reduce(math.min) + lngs.reduce(math.max)) / 2,
      );
    }

    return const LatLng(12.8797, 121.7740);
  }

  List<LatLng> _circlePoints(LatLng center, double radiusMeters) {
    const int segments = 72;
    const double earthRadius = 6378137.0;
    final points = <LatLng>[];

    for (int i = 0; i <= segments; i++) {
      final angle = (i * 360 / segments) * (math.pi / 180);
      final latOffset =
          radiusMeters / earthRadius * (180 / math.pi);
      final lngOffset = radiusMeters /
          (earthRadius * math.cos(center.latitude * math.pi / 180)) *
          (180 / math.pi);

      points.add(LatLng(
        center.latitude + latOffset * math.sin(angle),
        center.longitude + lngOffset * math.cos(angle),
      ));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_geofence?.name ?? 'Geofence'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest))
          : _geofence == null
              ? const Center(
                  child: Text('Geofence not found',
                      style: TextStyle(color: AppColors.mutedInk)))
              : Column(
                  children: [
                    // Map
                    SizedBox(
                      height: 300,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20)),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: _geofence!.isCircle ? 14.0 : 13.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'com.tanod.tanodmobile',
                            ),
                            if (_geofence!.isCircle &&
                                _geofence!.centerLat != null &&
                                _geofence!.centerLng != null &&
                                _geofence!.radius != null)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _circlePoints(
                                      LatLng(_geofence!.centerLat!,
                                          _geofence!.centerLng!),
                                      _geofence!.radius!,
                                    ),
                                    color: AppColors.forest
                                        .withValues(alpha: 0.15),
                                    borderColor: AppColors.forest,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            if (_geofence!.isPolygon &&
                                _geofence!.coordinates != null &&
                                _geofence!.coordinates!.length >= 3)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _geofence!.coordinates!
                                        .map((c) => LatLng(c.lat, c.lng))
                                        .toList(),
                                    color: AppColors.forest
                                        .withValues(alpha: 0.15),
                                    borderColor: AppColors.forest,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            // Center marker for circles
                            if (_geofence!.isCircle &&
                                _geofence!.centerLat != null &&
                                _geofence!.centerLng != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_geofence!.centerLat!,
                                        _geofence!.centerLng!),
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.forest,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.center_focus_strong,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Details
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Info card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DetailRow(
                                    label: 'Shape',
                                    value: _geofence!.isCircle
                                        ? 'Circle'
                                        : 'Polygon'),
                                if (_geofence!.isCircle &&
                                    _geofence!.radius != null)
                                  _DetailRow(
                                      label: 'Radius',
                                      value:
                                          '${_geofence!.radius!.toStringAsFixed(0)} m'),
                                _DetailRow(
                                    label: 'Alert On',
                                    value: _geofence!.alertOnLabel),
                                _DetailRow(
                                    label: 'Status',
                                    value: _geofence!.isActive
                                        ? 'Active'
                                        : 'Inactive'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Devices
                          const Text(
                            'Assigned Tractors',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_geofence!.devices.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No tractors assigned',
                                style: TextStyle(color: AppColors.mutedInk),
                              ),
                            )
                          else
                            ...(_geofence!.devices.map((device) {
                              final label =
                                  device.tractor?.label ?? 'Device #${device.id}';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.agriculture_rounded,
                                        size: 20, color: AppColors.pine),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(label,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink)),
                                    ),
                                  ],
                                ),
                              );
                            })),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.mutedInk)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}
