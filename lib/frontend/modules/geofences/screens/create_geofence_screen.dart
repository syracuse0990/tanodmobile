import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/geofence_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/frontend/shared/widgets/primary_button.dart';
import 'package:tanodmobile/models/domain/geo_fence.dart';

class CreateGeofenceScreen extends StatefulWidget {
  const CreateGeofenceScreen({super.key});

  @override
  State<CreateGeofenceScreen> createState() => _CreateGeofenceScreenState();
}

class _CreateGeofenceScreenState extends State<CreateGeofenceScreen> {
  final _nameController = TextEditingController();
  final MapController _mapController = MapController();

  String _shape = 'circle'; // 'circle' or 'polygon'
  String _alertOn = 'both';

  // Circle state
  LatLng? _circleCenter;
  double _circleRadius = 500; // meters

  // Polygon state
  final List<LatLng> _polygonPoints = [];

  // Selected devices
  final Set<int> _selectedDeviceIds = {};

  bool _devicesLoaded = false;

  static const _phCenter = LatLng(12.8797, 121.7740);

  @override
  void initState() {
    super.initState();
    context.read<GeoFenceProvider>().fetchAvailableDevices().then((_) {
      if (mounted) setState(() => _devicesLoaded = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      if (_shape == 'circle') {
        _circleCenter = point;
      } else {
        _polygonPoints.add(point);
      }
    });
  }

  void _removeLastPolygonPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() => _polygonPoints.removeLast());
    }
  }

  void _clearShape() {
    setState(() {
      _circleCenter = null;
      _circleRadius = 500;
      _polygonPoints.clear();
    });
  }

  List<LatLng> _circleVisualPoints(LatLng center, double radiusMeters) {
    const int segments = 72;
    const double earthRadius = 6378137.0;
    final points = <LatLng>[];

    for (int i = 0; i <= segments; i++) {
      final angle = (i * 360 / segments) * (math.pi / 180);
      final latOffset = radiusMeters / earthRadius * (180 / math.pi);
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

  bool get _canSubmit {
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedDeviceIds.isEmpty) return false;
    if (_shape == 'circle' && _circleCenter == null) return false;
    if (_shape == 'polygon' && _polygonPoints.length < 3) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final provider = context.read<GeoFenceProvider>();
    final success = await provider.createGeofence(
      name: _nameController.text.trim(),
      shape: _shape,
      alertOn: _alertOn,
      deviceIds: _selectedDeviceIds.toList(),
      centerLat: _shape == 'circle' ? _circleCenter!.latitude : null,
      centerLng: _shape == 'circle' ? _circleCenter!.longitude : null,
      radius: _shape == 'circle' ? _circleRadius : null,
      coordinates: _shape == 'polygon'
          ? _polygonPoints
              .map((p) => GeoFenceCoordinate(lat: p.latitude, lng: p.longitude))
              .toList()
          : null,
    );

    if (!mounted) return;

    if (success) {
      AppToast.show('Geofence created', type: ToastType.success);
      await provider.fetchGeofences();
      if (mounted) context.pop();
    } else {
      AppToast.show(provider.error ?? 'Failed to create geofence',
          type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GeoFenceProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Create Geofence'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_circleCenter != null || _polygonPoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear shape',
              onPressed: _clearShape,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                // Name field
                _SectionLabel(label: 'Name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Rice Paddy Zone A',
                    hintStyle: TextStyle(
                        color: AppColors.mutedInk.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.forest),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),

                const SizedBox(height: 18),

                // Shape toggle
                _SectionLabel(label: 'Shape'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleChip(
                        label: 'Circle',
                        icon: Icons.circle_outlined,
                        selected: _shape == 'circle',
                        onTap: () {
                          setState(() {
                            _shape = 'circle';
                            _polygonPoints.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ToggleChip(
                        label: 'Polygon',
                        icon: Icons.hexagon_outlined,
                        selected: _shape == 'polygon',
                        onTap: () {
                          setState(() {
                            _shape = 'polygon';
                            _circleCenter = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Map
                _SectionLabel(
                  label: _shape == 'circle'
                      ? 'Tap map to set center'
                      : 'Tap map to add polygon points',
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 260,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _phCenter,
                            initialZoom: 5.8,
                            onTap: _onMapTap,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'com.tanod.tanodmobile',
                            ),
                            // Circle overlay
                            if (_shape == 'circle' && _circleCenter != null)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _circleVisualPoints(
                                        _circleCenter!, _circleRadius),
                                    color: AppColors.forest
                                        .withValues(alpha: 0.15),
                                    borderColor: AppColors.forest,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            // Polygon overlay
                            if (_shape == 'polygon' &&
                                _polygonPoints.length >= 3)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _polygonPoints,
                                    color: AppColors.forest
                                        .withValues(alpha: 0.15),
                                    borderColor: AppColors.forest,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            // Polygon lines when < 3 points
                            if (_shape == 'polygon' &&
                                _polygonPoints.length >= 2 &&
                                _polygonPoints.length < 3)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _polygonPoints,
                                    strokeWidth: 2,
                                    color: AppColors.forest,
                                  ),
                                ],
                              ),
                            // Markers for polygon vertices / circle center
                            MarkerLayer(
                              markers: [
                                if (_shape == 'circle' && _circleCenter != null)
                                  Marker(
                                    point: _circleCenter!,
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.forest,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                          Icons.center_focus_strong,
                                          size: 12,
                                          color: Colors.white),
                                    ),
                                  ),
                                for (int i = 0;
                                    i < _polygonPoints.length;
                                    i++)
                                  Marker(
                                    point: _polygonPoints[i],
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.forest,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        // Undo polygon button
                        if (_shape == 'polygon' && _polygonPoints.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeLastPolygonPoint,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.undo_rounded,
                                    size: 20, color: AppColors.ink),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Radius slider for circle
                if (_shape == 'circle' && _circleCenter != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Radius:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.mutedInk)),
                      Expanded(
                        child: Slider(
                          value: _circleRadius,
                          min: 50,
                          max: 10000,
                          divisions: 199,
                          activeColor: AppColors.forest,
                          label: '${_circleRadius.toStringAsFixed(0)} m',
                          onChanged: (v) =>
                              setState(() => _circleRadius = v),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${_circleRadius.toStringAsFixed(0)} m',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_shape == 'polygon') ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_polygonPoints.length} point${_polygonPoints.length == 1 ? '' : 's'} placed'
                    '${_polygonPoints.length < 3 ? ' (min 3)' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedInk),
                  ),
                ],

                const SizedBox(height: 18),

                // Alert On
                _SectionLabel(label: 'Alert On'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ToggleChip(
                      label: 'Enter',
                      selected: _alertOn == 'enter',
                      onTap: () => setState(() => _alertOn = 'enter'),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Exit',
                      selected: _alertOn == 'exit',
                      onTap: () => setState(() => _alertOn = 'exit'),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Both',
                      selected: _alertOn == 'both',
                      onTap: () => setState(() => _alertOn = 'both'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Device selection
                _SectionLabel(label: 'Assign Tractors'),
                const SizedBox(height: 6),
                if (!_devicesLoaded)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.forest, strokeWidth: 2)),
                  )
                else if (provider.availableDevices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('No tractors available',
                        style: TextStyle(color: AppColors.mutedInk)),
                  )
                else
                  ...provider.availableDevices.map((device) {
                    final label =
                        device.tractor?.label ?? 'Device #${device.id}';
                    final selected = _selectedDeviceIds.contains(device.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedDeviceIds.remove(device.id);
                          } else {
                            _selectedDeviceIds.add(device.id);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.forest.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.forest
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 22,
                              color: selected
                                  ? AppColors.forest
                                  : AppColors.mutedInk
                                      .withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.agriculture_rounded,
                                size: 20, color: AppColors.pine),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.ink
                                      : AppColors.mutedInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Submit button
          StickyBottomButton(
            label: 'Create Geofence',
            isLoading: provider.submitting,
            onPressed: _canSubmit && !provider.submitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedInk,
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.forest : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18,
                  color: selected ? AppColors.forest : AppColors.mutedInk),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.forest : AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
