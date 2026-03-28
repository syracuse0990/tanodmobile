import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/home/screens/parts/map_fab_controls.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _showSatellite = false;
  int _selectedMarkerIndex = -1;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Philippines center
  static const _phCenter = LatLng(12.8797, 121.7740);
  static const _initialZoom = 5.8;

  // Sample tractor locations across Philippines
  static const List<_TractorPin> _tractors = [
    _TractorPin(15.5000, 120.9700, 'TRC-001', 'Nueva Ecija', true),
    _TractorPin(15.4827, 120.5920, 'TRC-002', 'Tarlac', true),
    _TractorPin(14.8120, 120.2896, 'TRC-003', 'Zambales', false),
    _TractorPin(16.4123, 120.5960, 'TRC-004', 'Benguet', true),
    _TractorPin(7.1907, 125.4553, 'TRC-005', 'Davao', true),
    _TractorPin(10.3157, 123.8854, 'TRC-006', 'Cebu', false),
    _TractorPin(13.1391, 123.7438, 'TRC-007', 'Albay', true),
    _TractorPin(8.4767, 124.6393, 'TRC-008', 'Bukidnon', true),
    _TractorPin(9.8500, 124.0150, 'TRC-009', 'Bohol', false),
    _TractorPin(14.2000, 121.1600, 'TRC-010', 'Laguna', true),
    _TractorPin(15.9754, 120.5711, 'TRC-011', 'Pangasinan', true),
    _TractorPin(11.5869, 122.7514, 'TRC-012', 'Iloilo', true),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<Marker> _buildMarkers() {
    return [
      for (int i = 0; i < _tractors.length; i++)
        Marker(
          point: LatLng(_tractors[i].lat, _tractors[i].lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => setState(() => _selectedMarkerIndex = i),
            child: _TractorMapMarker(
              isOnline: _tractors[i].isOnline,
              isSelected: _selectedMarkerIndex == i,
              pulseAnimation: _pulseAnimation,
            ),
          ),
        ),
    ];
  }

  void _recenter() {
    _mapController.move(_phCenter, _initialZoom);
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final onlineCount = _tractors.where((t) => t.isOnline).length;
    final offlineCount = _tractors.length - onlineCount;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Flutter Map ───
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _phCenter,
                initialZoom: _initialZoom,
                minZoom: 4,
                maxZoom: 18,
                onTap: (_, __) => setState(() => _selectedMarkerIndex = -1),
              ),
              children: [
                TileLayer(
                  urlTemplate: _showSatellite
                      ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.tanod.tanodmobile',
                  maxZoom: 20,
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),

          // ─── Top Header ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (_showSatellite ? const Color(0xFF1A2332) : Colors.white)
                        .withValues(alpha: 0.95),
                    (_showSatellite ? const Color(0xFF1A2332) : Colors.white)
                        .withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet Tracker',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _showSatellite ? Colors.white : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hi, ${user?.name ?? 'Farmer'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _showSatellite
                              ? Colors.white70
                              : AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _StatusChip(
                    label: '$onlineCount Online',
                    color: AppColors.success,
                    dark: _showSatellite,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: '$offlineCount Offline',
                    color: AppColors.danger,
                    dark: _showSatellite,
                  ),
                ],
              ),
            ),
          ),

          // ─── Selected Marker Detail Card ───
          if (_selectedMarkerIndex >= 0)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: _TractorDetailCard(
                tractor: _tractors[_selectedMarkerIndex],
                onClose: () => setState(() => _selectedMarkerIndex = -1),
              ),
            ),

          // ─── Floating side controls ───
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 80,
            child: MapFabControls(
              showSatellite: _showSatellite,
              onToggleSatellite: () =>
                  setState(() => _showSatellite = !_showSatellite),
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onRecenter: _recenter,
              dark: _showSatellite,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated tractor marker ───
class _TractorMapMarker extends StatelessWidget {
  const _TractorMapMarker({
    required this.isOnline,
    required this.isSelected,
    required this.pulseAnimation,
  });

  final bool isOnline;
  final bool isSelected;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.danger;

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring for online tractors
            if (isOnline)
              Container(
                width: 36 * pulseAnimation.value,
                height: 36 * pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(
                    alpha: 0.3 * (1.0 - pulseAnimation.value),
                  ),
                ),
              ),
            // Selection glow
            if (isSelected)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            // Core marker
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.agriculture_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.dark,
  });

  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TractorDetailCard extends StatelessWidget {
  const _TractorDetailCard({required this.tractor, required this.onClose});

  final _TractorPin tractor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (tractor.isOnline ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.agriculture_rounded,
              color: tractor.isOnline ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tractor.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tractor.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tractor.isOnline
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tractor.isOnline ? 'Active' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tractor.isOnline
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${tractor.lat.toStringAsFixed(4)}, ${tractor.lng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TractorPin {
  const _TractorPin(
    this.lat,
    this.lng,
    this.label,
    this.location,
    this.isOnline,
  );

  final double lat;
  final double lng;
  final String label;
  final String location;
  final bool isOnline;
}
