import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/home/screens/parts/map_fab_controls.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';
import 'package:tanodmobile/models/domain/tractor_location.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  bool _showSatellite = false;
  int _selectedMarkerIndex = -1;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final TractorProvider _tractorProvider;

  /// Track last known lat/lng of the focused tractor to detect movement.
  double? _lastFocusedLat;
  double? _lastFocusedLng;

  // Philippines center
  static const _phCenter = LatLng(12.8797, 121.7740);
  static const _initialZoom = 5.8;
  static const _focusZoom = 15.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tractorProvider = context.read<TractorProvider>();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start polling
    _tractorProvider.startPolling();
    _tractorProvider.addListener(_onTractorDataChanged);
  }

  @override
  void dispose() {
    _tractorProvider.removeListener(_onTractorDataChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// When focused on a tractor, pan the map camera to follow its new position.
  void _onTractorDataChanged() {
    final focusedId = _tractorProvider.focusedTractorId;
    if (focusedId == null) {
      _lastFocusedLat = null;
      _lastFocusedLng = null;
      return;
    }

    final focused = _tractorProvider.withLocation
        .cast<TractorLocation?>()
        .firstWhere((t) => t?.id == focusedId, orElse: () => null);
    if (focused == null) return;

    // Only pan if position actually changed.
    if (_lastFocusedLat != focused.lat || _lastFocusedLng != focused.lng) {
      _lastFocusedLat = focused.lat;
      _lastFocusedLng = focused.lng;
      _mapController.move(
        LatLng(focused.lat, focused.lng),
        _mapController.camera.zoom,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (_tractorProvider.homeVisible) _tractorProvider.startPolling();
    } else if (state == AppLifecycleState.paused) {
      _tractorProvider.stopPolling();
    }
  }

  void _onMarkerTap(int index, List<TractorLocation> tractors) {
    final tractor = tractors[index];
    final provider = context.read<TractorProvider>();

    setState(() => _selectedMarkerIndex = index);

    // Track initial position so the listener can detect movement.
    _lastFocusedLat = tractor.lat;
    _lastFocusedLng = tractor.lng;

    // Focus on the tractor - zoom in and switch to 10s polling
    provider.focusTractor(tractor.id);
    _mapController.move(LatLng(tractor.lat, tractor.lng), _focusZoom);
  }

  void _clearFocus() {
    final provider = context.read<TractorProvider>();
    setState(() => _selectedMarkerIndex = -1);
    _lastFocusedLat = null;
    _lastFocusedLng = null;
    provider.clearFocus();
  }

  List<Marker> _buildMarkers(List<TractorLocation> tractors) {
    return [
      for (int i = 0; i < tractors.length; i++)
        Marker(
          point: LatLng(tractors[i].lat, tractors[i].lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _onMarkerTap(i, tractors),
            child: _TractorMapMarker(
              isOnline: tractors[i].isOnline,
              isIdle: tractors[i].isIdle,
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

  Future<void> _shareLocation(TractorLocation tractor) async {
    if (tractor.deviceId == null) return;

    final provider = context.read<TractorProvider>();
    final result = await provider.createShare(tractor.deviceId!);

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      final url = result['url'] as String;
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share link copied!\n$url'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create share link'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _viewTrackHistory(TractorLocation tractor) {
    if (tractor.deviceId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TrackHistorySheet(tractor: tractor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final tractorProvider = context.watch<TractorProvider>();
    final visibleTractors = tractorProvider.withLocation;
    final onlineCount = tractorProvider.onlineCount;
    final idleCount = tractorProvider.idleCount;
    final offlineCount = tractorProvider.offlineCount;

    // Reset selected index if out of bounds after data refresh
    if (_selectedMarkerIndex >= visibleTractors.length) {
      _selectedMarkerIndex = -1;
    }

    // Find selected tractor for FAB actions
    final TractorLocation? selectedTractor =
        _selectedMarkerIndex >= 0 &&
            _selectedMarkerIndex < visibleTractors.length
        ? visibleTractors[_selectedMarkerIndex]
        : null;

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
                onTap: (_, __) => _clearFocus(),
              ),
              children: [
                TileLayer(
                  urlTemplate: _showSatellite
                      ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.tanod.tanodmobile',
                  maxZoom: 20,
                ),
                MarkerLayer(markers: _buildMarkers(visibleTractors)),
              ],
            ),
          ),

          // ─── Loading indicator (first load only) ───
          if (tractorProvider.loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.success),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fleet Tracker',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _showSatellite
                                ? Colors.white
                                : AppColors.ink,
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
                  ),
                  _StatusChip(
                    label: '$onlineCount',
                    color: AppColors.success,
                    dark: _showSatellite,
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '$idleCount',
                    color: AppColors.warning,
                    dark: _showSatellite,
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '$offlineCount',
                    color: AppColors.danger,
                    dark: _showSatellite,
                  ),
                ],
              ),
            ),
          ),

          // ─── Selected Marker Detail Card ───
          if (selectedTractor != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: _TractorDetailCard(
                tractor: selectedTractor,
                onClose: _clearFocus,
                onShare: () => _shareLocation(selectedTractor),
                onTrackHistory: () => _viewTrackHistory(selectedTractor),
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
              secondsUntilPoll: tractorProvider.secondsUntilPoll,
              showTractorActions: selectedTractor != null,
              onShareLocation: selectedTractor != null
                  ? () => _shareLocation(selectedTractor)
                  : null,
              onTrackHistory: selectedTractor != null
                  ? () => _viewTrackHistory(selectedTractor)
                  : null,
              onClearFocus: _clearFocus,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper to resolve tractor marker color ───
Color _tractorColor(TractorLocation t) {
  if (t.isMoving) return AppColors.success;
  if (t.isIdle) return AppColors.warning;
  return AppColors.danger;
}

// ─── Animated tractor marker ───
class _TractorMapMarker extends StatelessWidget {
  const _TractorMapMarker({
    required this.isOnline,
    required this.isIdle,
    required this.isSelected,
    required this.pulseAnimation,
  });

  final bool isOnline;
  final bool isIdle;
  final bool isSelected;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (!isOnline) {
      color = AppColors.danger;
    } else if (isIdle) {
      color = AppColors.warning;
    } else {
      color = AppColors.success;
    }

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
              child: const Icon(
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
  const _TractorDetailCard({
    required this.tractor,
    required this.onClose,
    required this.onShare,
    required this.onTrackHistory,
  });

  final TractorLocation tractor;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onTrackHistory;

  @override
  Widget build(BuildContext context) {
    final color = _tractorColor(tractor);

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.agriculture_rounded, color: color),
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
                      tractor.subtitle,
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
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tractor.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (tractor.speed != null && tractor.isOnline) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${tractor.speed!.toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            '${tractor.lat.toStringAsFixed(4)}, ${tractor.lng.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedInk,
                            ),
                            overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: Icons.share_location_rounded,
                  label: 'Share Location',
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardAction(
                  icon: Icons.route_rounded,
                  label: 'Track History',
                  onTap: onTrackHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.pine),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Track History Bottom Sheet ───
class _TrackHistorySheet extends StatefulWidget {
  const _TrackHistorySheet({required this.tractor});

  final TractorLocation tractor;

  @override
  State<_TrackHistorySheet> createState() => _TrackHistorySheetState();
}

class _TrackHistorySheetState extends State<_TrackHistorySheet>
    with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'today';
  bool _loading = false;
  List<LatLng> _trackPoints = [];
  String? _error;

  // Playback
  late final AnimationController _playController;
  double _playbackSpeed = 1.0;
  bool get _isPlaying => _playController.isAnimating;
  final MapController _trackMapController = MapController();

  final List<Map<String, String>> _periods = [
    {'value': 'today', 'label': 'Today'},
    {'value': 'yesterday', 'label': 'Yesterday'},
    {'value': '3days', 'label': '3 Days'},
    {'value': 'week', 'label': 'This Week'},
  ];

  @override
  void initState() {
    super.initState();
    _playController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _playController.addListener(() => setState(() {}));
    _fetchTrack();
  }

  @override
  void dispose() {
    _playController.dispose();
    _trackMapController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrack() async {
    if (widget.tractor.deviceId == null) return;

    _playController.reset();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<TractorProvider>();
      final response = await provider.fetchTrackData(
        widget.tractor.deviceId!,
        _selectedPeriod,
      );

      final points = (response?['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (p) => LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ),
          )
          .toList();

      setState(() {
        _trackPoints = points;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load track data';
        _loading = false;
      });
    }
  }

  void _togglePlayback() {
    if (_trackPoints.length < 2) return;

    if (_isPlaying) {
      _playController.stop();
    } else {
      // Adjust duration based on number of points and speed
      final baseSecs = (_trackPoints.length * 0.15).clamp(10.0, 120.0);
      _playController.duration = Duration(
        milliseconds: (baseSecs * 1000 / _playbackSpeed).round(),
      );

      if (_playController.isCompleted) {
        _playController.forward(from: 0);
      } else {
        _playController.forward();
      }
    }
    setState(() {});
  }

  void _setSpeed(double speed) {
    final wasPlaying = _isPlaying;
    if (wasPlaying) _playController.stop();

    _playbackSpeed = speed;
    final baseSecs = (_trackPoints.length * 0.15).clamp(10.0, 120.0);
    _playController.duration = Duration(
      milliseconds: (baseSecs * 1000 / _playbackSpeed).round(),
    );

    if (wasPlaying) {
      _playController.forward();
    }
    setState(() {});
  }

  LatLng _interpolatedPosition() {
    if (_trackPoints.length < 2) return _trackPoints.first;

    final progress = _playController.value;
    final totalSegments = _trackPoints.length - 1;
    final exact = progress * totalSegments;
    final idx = exact.floor().clamp(0, totalSegments - 1);
    final t = exact - idx;

    final from = _trackPoints[idx];
    final to = _trackPoints[idx + 1];

    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTrack = _trackPoints.length >= 2;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: AppColors.pine),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Track History — ${widget.tractor.label}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22),
                ),
              ],
            ),
          ),

          // Period chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _periods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final period = _periods[index];
                final isActive = _selectedPeriod == period['value'];
                return ChoiceChip(
                  label: Text(period['label']!),
                  selected: isActive,
                  onSelected: (_) {
                    setState(() => _selectedPeriod = period['value']!);
                    _fetchTrack();
                  },
                  selectedColor: AppColors.pine,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.ink,
                  ),
                  backgroundColor: AppColors.canvas,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide.none,
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Map
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.success),
                  )
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  )
                : _trackPoints.isEmpty
                ? const Center(
                    child: Text(
                      'No track data for this period',
                      style: TextStyle(color: AppColors.mutedInk),
                    ),
                  )
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: FlutterMap(
                      mapController: _trackMapController,
                      options: MapOptions(
                        initialCenter: _trackPoints.first,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                          userAgentPackageName: 'com.tanod.tanodmobile',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _trackPoints,
                              strokeWidth: 3.5,
                              color: AppColors.pine,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            // Start marker
                            Marker(
                              point: _trackPoints.first,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // End marker
                            Marker(
                              point: _trackPoints.last,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.danger,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Animated tractor marker
                            if (hasTrack && _playController.value > 0)
                              Marker(
                                point: _interpolatedPosition(),
                                width: 32,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.pine,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.pine.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.agriculture_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),

          // ─── Playback controls ───
          if (!_loading && _trackPoints.length >= 2)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress slider
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: AppColors.pine,
                      inactiveTrackColor: AppColors.ink.withValues(alpha: 0.08),
                      thumbColor: AppColors.pine,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: _playController.value,
                      onChanged: (v) {
                        _playController.value = v;
                      },
                      onChangeStart: (_) {
                        if (_isPlaying) _playController.stop();
                      },
                    ),
                  ),
                  Row(
                    children: [
                      // Play/Pause button
                      Material(
                        color: AppColors.pine,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: _togglePlayback,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : _playController.isCompleted
                                  ? Icons.replay_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Points info
                      Text(
                        '${(_playController.value * _trackPoints.length).round()} / ${_trackPoints.length} pts',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedInk,
                        ),
                      ),
                      const Spacer(),
                      // Speed selector
                      for (final speed in [1.0, 2.0, 4.0])
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Material(
                            color: _playbackSpeed == speed
                                ? AppColors.pine
                                : AppColors.canvas,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _setSpeed(speed),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  '${speed.toInt()}x',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _playbackSpeed == speed
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
