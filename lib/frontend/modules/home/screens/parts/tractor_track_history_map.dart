import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class TractorTrackHistoryMap extends StatefulWidget {
  const TractorTrackHistoryMap({
    super.key,
    required this.trailPoints,
    required this.playbackIndex,
    this.interpolatedPosition,
    required this.currentSpeed,
    required this.currentDirection,
  });

  final List<LatLng> trailPoints;
  final int playbackIndex;
  final LatLng? interpolatedPosition;
  final double currentSpeed;
  final double currentDirection;

  @override
  State<TractorTrackHistoryMap> createState() => _TractorTrackHistoryMapState();
}

class _TractorTrackHistoryMapState extends State<TractorTrackHistoryMap> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(covariant TractorTrackHistoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_shouldRefitTrack(oldWidget.trailPoints, widget.trailPoints)) {
      _fitTrackBounds();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trailPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final playbackIndex = widget.playbackIndex.clamp(
      0,
      widget.trailPoints.length - 1,
    );
    final currentPoint =
        widget.interpolatedPosition ?? widget.trailPoints[playbackIndex];
    final progressPoints = widget.trailPoints
        .take(playbackIndex + 1)
        .toList(growable: true);
    // If we have an interpolated position, include it in the progress path
    // for a perfectly smooth trailing line
    if (widget.interpolatedPosition != null &&
        playbackIndex < widget.trailPoints.length - 1) {
      progressPoints.add(widget.interpolatedPosition!);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPoint,
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 18,
              onMapReady: () {
                _mapReady = true;
                _fitTrackBounds();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.tanod.tanodmobile',
                maxZoom: 20,
              ),
              PolylineLayer(
                polylines: [
                  if (widget.trailPoints.length > 1)
                    Polyline(
                      points: widget.trailPoints,
                      strokeWidth: 4,
                      color: AppColors.pine.withValues(alpha: 0.18),
                    ),
                  if (progressPoints.length > 1)
                    Polyline(
                      points: progressPoints,
                      strokeWidth: 5,
                      color: AppColors.pine,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  _edgeMarker(
                    point: widget.trailPoints.first,
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.success,
                  ),
                  if (widget.trailPoints.length > 1)
                    _edgeMarker(
                      point: widget.trailPoints.last,
                      icon: Icons.flag_rounded,
                      color: AppColors.danger,
                    ),
                  _playbackMarker(
                    point: currentPoint,
                    speed: widget.currentSpeed,
                    direction: widget.currentDirection,
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _fitTrackBounds,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.fit_screen_rounded,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldRefitTrack(List<LatLng> oldPoints, List<LatLng> newPoints) {
    if (oldPoints.length != newPoints.length) {
      return true;
    }

    if (oldPoints.isEmpty || newPoints.isEmpty) {
      return false;
    }

    final oldFirst = oldPoints.first;
    final newFirst = newPoints.first;
    final oldLast = oldPoints.last;
    final newLast = newPoints.last;

    return oldFirst.latitude != newFirst.latitude ||
        oldFirst.longitude != newFirst.longitude ||
        oldLast.latitude != newLast.latitude ||
        oldLast.longitude != newLast.longitude;
  }

  void _fitTrackBounds() {
    if (!_mapReady || widget.trailPoints.isEmpty || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.trailPoints.isEmpty) {
        return;
      }

      if (widget.trailPoints.length == 1) {
        _mapController.move(widget.trailPoints.first, 16);
        return;
      }

      final bounds = LatLngBounds.fromPoints(widget.trailPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    });
  }

  Marker _edgeMarker({
    required LatLng point,
    required IconData icon,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 38,
      height: 38,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Marker _playbackMarker({
    required LatLng point,
    required double speed,
    required double direction,
  }) {
    final assetPath = _tractorAssetForSpeed(speed);
    // Convert bearing (0°=North, clockwise) to Flutter rotation
    // (0 radians = East, clockwise)
    final rotationRadians = (direction - 90) * 3.141592653589793 / 180;

    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: rotationRadians,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

String _tractorAssetForSpeed(double speed) {
  if (speed >= 3) {
    return 'assets/images/green_tractor.png';
  }

  return 'assets/images/yellow_tractor.png';
}
