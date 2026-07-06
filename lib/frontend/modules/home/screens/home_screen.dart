import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/home/screens/parts/map_fab_controls.dart';
import 'package:tanodmobile/frontend/modules/home/screens/parts/tractor_map_action_sheets.dart';
import 'package:tanodmobile/frontend/modules/home/screens/parts/tractor_insight_sheet.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';
import 'package:tanodmobile/models/domain/tractor_location.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSatellite = false;
  bool _isMapReady = false;
  int? _selectedTractorId;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final TractorProvider _tractorProvider;

  /// Smooth marker movement animation.
  late final AnimationController _moveController;
  final Map<int, LatLng> _prevPositions = {};
  final Map<int, LatLng> _targetPositions = {};

  /// Smooth camera animation for focused tractor.
  AnimationController? _cameraAnimController;
  Timer? _searchDebounce;

  /// Track last known lat/lng of the focused tractor to detect movement.
  double? _lastFocusedLat;
  double? _lastFocusedLng;

  // Philippines center
  static const _phCenter = LatLng(12.8797, 121.7740);
  static const _initialZoom = 5.8;
  static const _focusZoom = 15.0;
  static const _clusterGridSize = 90.0;
  static const _clusterBreakoutZoom = 14.5;
  static const _clusterThreshold = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tractorProvider = context.read<TractorProvider>();
    _searchController.text = _tractorProvider.searchQuery;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _moveController.addListener(() {
      if (mounted) setState(() {});
    });

    // Start polling
    _tractorProvider.startPolling();
    _tractorProvider.addListener(_onTractorDataChanged);
  }

  @override
  void dispose() {
    _tractorProvider.removeListener(_onTractorDataChanged);
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    _moveController.dispose();
    _cameraAnimController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// When tractor data changes, animate markers to new positions and
  /// smoothly pan the camera if following a focused tractor.
  void _onTractorDataChanged() {
    // --- Animate marker positions ---
    final tractors = _tractorProvider.withLocation;
    bool anyMoved = false;
    for (final t in tractors) {
      final newPos = LatLng(t.lat, t.lng);
      final oldTarget = _targetPositions[t.id];
      if (oldTarget != null &&
          (oldTarget.latitude != newPos.latitude ||
              oldTarget.longitude != newPos.longitude)) {
        // Position changed – start from current interpolated position.
        _prevPositions[t.id] = _getAnimatedPosition(t.id, oldTarget);
        _targetPositions[t.id] = newPos;
        anyMoved = true;
      } else if (oldTarget == null) {
        // First time seeing this tractor – no animation needed.
        _prevPositions[t.id] = newPos;
        _targetPositions[t.id] = newPos;
      }
    }
    if (anyMoved) {
      _moveController.forward(from: 0.0);
    }

    // --- Smooth camera follow for focused tractor ---
    final focusedId = _tractorProvider.focusedTractorId;
    if (focusedId == null) {
      _lastFocusedLat = null;
      _lastFocusedLng = null;
      return;
    }

    final focused = tractors
        .cast<TractorLocation?>()
        .firstWhere((t) => t?.id == focusedId, orElse: () => null);
    if (focused == null) return;

    if (_lastFocusedLat != focused.lat || _lastFocusedLng != focused.lng) {
      _lastFocusedLat = focused.lat;
      _lastFocusedLng = focused.lng;
      _animateCamera(LatLng(focused.lat, focused.lng));
    }
  }

  /// Interpolate between previous and target position for a tractor.
  LatLng _getAnimatedPosition(int tractorId, LatLng fallback) {
    final prev = _prevPositions[tractorId];
    final target = _targetPositions[tractorId];
    if (prev == null || target == null) return fallback;
    final t = Curves.easeOutCubic.transform(_moveController.value);
    return LatLng(
      prev.latitude + (target.latitude - prev.latitude) * t,
      prev.longitude + (target.longitude - prev.longitude) * t,
    );
  }

  /// Smoothly animate the map camera to [target] with optional [targetZoom].
  void _animateCamera(LatLng target, {double? targetZoom}) {
    if (!_isMapReady) {
      return;
    }

    _cameraAnimController?.dispose();
    final start = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final endZoom = targetZoom ?? startZoom;

    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final curved = CurvedAnimation(
      parent: _cameraAnimController!,
      curve: Curves.easeOutCubic,
    );
    curved.addListener(() {
      final v = curved.value;
      _mapController.move(
        LatLng(
          start.latitude + (target.latitude - start.latitude) * v,
          start.longitude + (target.longitude - start.longitude) * v,
        ),
        startZoom + (endZoom - startZoom) * v,
      );
    });
    _cameraAnimController!.forward();
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

  void _onMarkerTap(TractorLocation tractor) {
    final provider = context.read<TractorProvider>();

    setState(() => _selectedTractorId = tractor.id);

    // Track initial position so the listener can detect movement.
    _lastFocusedLat = tractor.lat;
    _lastFocusedLng = tractor.lng;

    // Focus on the tractor - zoom in and switch to 10s polling
    provider.focusTractor(tractor.id);
    _animateCamera(LatLng(tractor.lat, tractor.lng), targetZoom: _focusZoom);
  }

  void _clearFocus() {
    final provider = context.read<TractorProvider>();
    setState(() => _selectedTractorId = null);
    _lastFocusedLat = null;
    _lastFocusedLng = null;
    provider.clearFocus();
  }

  void _clearFocusAndRecenter() {
    _clearFocus();
    _recenter();
  }

  List<Marker> _buildMarkers(List<TractorLocation> tractors) {
    final hasSearchQuery = _tractorProvider.searchQuery.isNotEmpty;
    final currentZoom = _isMapReady ? _mapController.camera.zoom : _initialZoom;
    final shouldCluster =
      _isMapReady &&
        _selectedTractorId == null &&
        !_tractorProvider.isFocused &&
        !hasSearchQuery &&
        tractors.length > _clusterThreshold &&
        currentZoom < _clusterBreakoutZoom;

    if (!shouldCluster) {
      return [
        for (int i = 0; i < tractors.length; i++)
          Marker(
            point: _getAnimatedPosition(
              tractors[i].id,
              LatLng(tractors[i].lat, tractors[i].lng),
            ),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _onMarkerTap(tractors[i]),
              child: _TractorMapMarker(
                isOnline: tractors[i].isOnline,
                isIdle: tractors[i].isIdle,
                isSelected: _selectedTractorId == tractors[i].id,
                pulseAnimation: _pulseAnimation,
              ),
            ),
          ),
      ];
    }

    final clusters = _clusterTractors(tractors, currentZoom);

    return [
      for (final cluster in clusters)
        if (cluster.tractors.length == 1)
          Marker(
            point: _getAnimatedPosition(
              cluster.tractors.first.id,
              LatLng(
                cluster.tractors.first.lat,
                cluster.tractors.first.lng,
              ),
            ),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _onMarkerTap(cluster.tractors.first),
              child: _TractorMapMarker(
                isOnline: cluster.tractors.first.isOnline,
                isIdle: cluster.tractors.first.isIdle,
                isSelected:
                    _selectedTractorId == cluster.tractors.first.id,
                pulseAnimation: _pulseAnimation,
              ),
            ),
          )
        else
          Marker(
            point: cluster.center,
            width: _clusterMarkerSize(cluster.tractors.length),
            height: _clusterMarkerSize(cluster.tractors.length),
            child: GestureDetector(
              onTap: () => _zoomToCluster(cluster),
              child: _ClusterMapMarker(count: cluster.tractors.length),
            ),
          ),
    ];
  }

  List<_TractorCluster> _clusterTractors(
    List<TractorLocation> tractors,
    double zoom,
  ) {
    final scale = 256.0 * math.pow(2, zoom).toDouble();
    final clusterMap = <String, List<TractorLocation>>{};

    for (final tractor in tractors) {
      final lat = tractor.lat;
      final lng = tractor.lng;
      final sinLat = math.sin((lat * math.pi) / 180);
      final x = ((lng + 180) / 360) * scale;
      final y =
          (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) *
          scale;
      final key =
          '${(x / _clusterGridSize).floor()}:${(y / _clusterGridSize).floor()}';

      (clusterMap[key] ??= <TractorLocation>[]).add(tractor);
    }

    return clusterMap.values.map((clusterTractors) {
      if (clusterTractors.length == 1) {
        final tractor = clusterTractors.first;
        return _TractorCluster(
          center: LatLng(tractor.lat, tractor.lng),
          tractors: clusterTractors,
        );
      }

      final totalLat = clusterTractors.fold<double>(
        0,
        (sum, tractor) => sum + tractor.lat,
      );
      final totalLng = clusterTractors.fold<double>(
        0,
        (sum, tractor) => sum + tractor.lng,
      );

      return _TractorCluster(
        center: LatLng(
          totalLat / clusterTractors.length,
          totalLng / clusterTractors.length,
        ),
        tractors: clusterTractors,
      );
    }).toList(growable: false);
  }

  double _clusterMarkerSize(int count) {
    if (count >= 500) {
      return 60;
    }
    if (count >= 100) {
      return 52;
    }
    if (count >= 25) {
      return 44;
    }
    return 36;
  }

  void _zoomToCluster(_TractorCluster cluster) {
    if (!_isMapReady) {
      return;
    }

    final nextZoom = math.min(
      _mapController.camera.zoom + 2,
      _clusterBreakoutZoom,
    );
    _animateCamera(cluster.center, targetZoom: nextZoom);
  }

  void _recenter() {
    _animateCamera(_phCenter, targetZoom: _initialZoom);
  }

  void _zoomIn() {
    if (!_isMapReady) {
      return;
    }

    _animateCamera(
      _mapController.camera.center,
      targetZoom: math.min(_mapController.camera.zoom + 1, 18),
    );
  }

  void _zoomOut() {
    if (!_isMapReady) {
      return;
    }

    _animateCamera(
      _mapController.camera.center,
      targetZoom: math.max(_mapController.camera.zoom - 1, 4),
    );
  }

  Future<void> _showTractorInsight(
    TractorLocation tractor,
    TractorInsightTab initialTab,
  ) {
    return showTractorInsightSheet(
      context,
      tractor: tractor,
      initialTab: initialTab,
    );
  }

  Future<void> _showShareLocationSheet(TractorLocation tractor) {
    return showTractorShareLocationSheet(
      context,
      tractor: tractor,
      provider: _tractorProvider,
    );
  }

  Future<void> _showTrackHistorySheet(TractorLocation tractor) {
    return showTractorTrackHistorySheet(
      context,
      tractor: tractor,
      provider: _tractorProvider,
    );
  }

  Future<void> _applySearchQuery(
    String value, {
    bool recenterToOverview = false,
  }) async {
    final shouldClearFocus = _selectedTractorId != null;
    if (shouldClearFocus) {
      setState(() {
        _selectedTractorId = null;
      });
      _lastFocusedLat = null;
      _lastFocusedLng = null;
    }

    final normalized = value.trim();
    await _tractorProvider.setSearchQuery(
      normalized,
      clearFocus: shouldClearFocus,
    );

    if (!mounted || _tractorProvider.searchQuery != normalized) {
      return;
    }

    if (recenterToOverview) {
      _recenter();
      return;
    }

    if (normalized.isNotEmpty) {
      _fitVisibleSearchResults();
    }
  }

  void _fitVisibleSearchResults() {
    final tractors = _tractorProvider.withLocation;
    if (tractors.isEmpty || !mounted || !_isMapReady) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tractorProvider.searchQuery.isEmpty) {
        return;
      }

      final visibleTractors = _tractorProvider.withLocation;
      if (visibleTractors.isEmpty) {
        return;
      }

      if (visibleTractors.length == 1) {
        final onlyMatch = visibleTractors.first;
        _animateCamera(
          LatLng(onlyMatch.lat, onlyMatch.lng),
          targetZoom: _focusZoom,
        );
        return;
      }

      final points = visibleTractors
          .map((tractor) => LatLng(tractor.lat, tractor.lng))
          .toList(growable: false);
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 120),
        ),
      );
    });
  }

  void _onSearchChanged(String value) {
    if (mounted) {
      setState(() {});
    }

    _searchDebounce?.cancel();

    if (value.trim().isEmpty) {
      unawaited(_applySearchQuery('', recenterToOverview: true));
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      unawaited(_applySearchQuery(value));
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();

    setState(() {
      _searchController.clear();
    });

    unawaited(_applySearchQuery('', recenterToOverview: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final tractorProvider = context.watch<TractorProvider>();
    final visibleTractors = tractorProvider.withLocation;
    final movingCount = tractorProvider.movingCount;
    final idleCount = tractorProvider.idleCount;
    final offlineCount = tractorProvider.offlineCount;
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final appliedSearchQuery = tractorProvider.searchQuery;
    final hasAppliedSearchQuery = appliedSearchQuery.isNotEmpty;
    final showNoSearchMatches =
      hasAppliedSearchQuery &&
      !tractorProvider.loading &&
      tractorProvider.tractors.isEmpty;
    final showNoSearchLocations =
      hasAppliedSearchQuery &&
      !tractorProvider.loading &&
      tractorProvider.tractors.isNotEmpty &&
      visibleTractors.isEmpty;

    // Find selected tractor for FAB actions
    final TractorLocation? selectedTractor =
        tractorProvider.tractors.cast<TractorLocation?>().firstWhere(
          (tractor) => tractor?.id == _selectedTractorId,
          orElse: () => null,
        );

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
                onMapReady: () {
                  if (!mounted || _isMapReady) {
                    return;
                  }

                  setState(() {
                    _isMapReady = true;
                  });
                },
                onPositionChanged: (_, hasGesture) {
                  if (mounted) {
                    setState(() {});
                  }
                },
                onTap: (_, _) => _clearFocus(),
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

          if (showNoSearchMatches || showNoSearchLocations)
            Positioned(
              left: 20,
              right: 20,
              top: MediaQuery.paddingOf(context).top + 118,
              child: _SearchFeedbackCard(
                icon: showNoSearchMatches
                    ? Icons.search_off_rounded
                    : Icons.location_off_rounded,
                title: showNoSearchMatches
                    ? 'No tractors matched your search'
                    : 'Matches found without live location',
                message: showNoSearchMatches
                    ? 'Try another tractor name, IMEI, or FCA name for "$appliedSearchQuery".'
                    : 'The tractors matching "$appliedSearchQuery" do not have live coordinates yet.',
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
              child: Column(
                children: [
                  Row(
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
                        label: '$movingCount',
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
                  if (!tractorProvider.isFocused) ...[
                    const SizedBox(height: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _showSatellite
                            ? const Color(0xFF334155)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _showSatellite
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.ink.withValues(alpha: 0.06),
                        ),
                        boxShadow: _showSatellite
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: AppColors.ink.withValues(alpha: 0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      cursorColor: _showSatellite ? Colors.white : AppColors.forest,
                      style: TextStyle(
                        color: _showSatellite ? AppColors.mutedInk : AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search tractor, IMEI, or FCA name',
                        hintStyle: TextStyle(
                          color: _showSatellite
                              ? AppColors.mutedInk
                              : AppColors.mutedInk,
                          fontSize: 13,
                        ),
                        iconColor: _showSatellite
                            ? AppColors.mutedInk
                            : AppColors.mutedInk,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: hasSearchQuery
                            ? IconButton(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  ],
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
                onClose: _clearFocusAndRecenter,
                onShowFcaDetails: () => _showTractorInsight(
                  selectedTractor,
                  TractorInsightTab.fcaDetails,
                ),
                onShowPmsHistory: () => _showTractorInsight(
                  selectedTractor,
                  TractorInsightTab.pmsHistory,
                ),
              ),
            ),

          // ─── Floating side controls ───
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top +
                (tractorProvider.isFocused ? 80 : 155),
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
                  ? () => _showShareLocationSheet(selectedTractor)
                  : null,
              onViewTrackHistory: selectedTractor != null
                  ? () => _showTrackHistorySheet(selectedTractor)
                  : null,
              onClearFocus: _clearFocusAndRecenter,
            ),
          ),
        ],
      ),
    );
  }
}

class _TractorCluster {
  const _TractorCluster({required this.center, required this.tractors});

  final LatLng center;
  final List<TractorLocation> tractors;
}

// ─── Helper to resolve tractor marker color ───
Color _tractorColor(TractorLocation t) {
  if (t.isMoving) return AppColors.success;
  if (t.isIdle) return AppColors.warning;
  return AppColors.danger;
}

String _tractorAssetForState({
  required bool isOnline,
  required bool isIdle,
}) {
  if (!isOnline) {
    return 'assets/images/red_tractor.png';
  }

  if (isIdle) {
    return 'assets/images/yellow_tractor.png';
  }

  return 'assets/images/green_tractor.png';
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
    final assetPath = _tractorAssetForState(
      isOnline: isOnline,
      isIdle: isIdle,
    );

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
                width: 38,
                height: 38,
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
            // Tractor marker image from the web Fleet tracker assets
            Container(
              width: isSelected ? 34 : 30,
              height: isSelected ? 34 : 30,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClusterMapMarker extends StatelessWidget {
  const _ClusterMapMarker({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final size = count >= 500
        ? 60.0
        : count >= 100
        ? 52.0
        : count >= 25
        ? 44.0
        : 36.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF6D6AF8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D6AF8).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: count >= 100 ? 13 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchFeedbackCard extends StatelessWidget {
  const _SearchFeedbackCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.pine),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    required this.onShowFcaDetails,
    required this.onShowPmsHistory,
  });

  final TractorLocation tractor;
  final VoidCallback onClose;
  final VoidCallback onShowFcaDetails;
  final VoidCallback onShowPmsHistory;

  @override
  Widget build(BuildContext context) {
    final color = _tractorColor(tractor);
    final assetPath = _tractorAssetForState(
      isOnline: tractor.isOnline,
      isIdle: tractor.isIdle,
    );
    final imei = tractor.imei;
    final imeiLabel = imei != null && imei.trim().isNotEmpty
        ? imei
        : 'Unavailable';
    final lastOnlineLabel = tractor.isOnline ? 'Last update' : 'Last online';

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
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: AppColors.mutedInk,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$lastOnlineLabel ${tractor.lastOnlineLabel}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedInk,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.numbers_rounded,
                          size: 13,
                          color: AppColors.mutedInk,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'IMEI $imeiLabel',
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
                  icon: Icons.badge_rounded,
                  label: 'FCA Details',
                  onTap: onShowFcaDetails,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardAction(
                  icon: Icons.history_rounded,
                  label: 'PMS History',
                  onTap: onShowPmsHistory,
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
