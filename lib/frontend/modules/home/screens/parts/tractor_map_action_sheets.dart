import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/tractor_provider.dart';
import 'package:tanodmobile/frontend/modules/home/screens/parts/tractor_track_history_map.dart';
import 'package:tanodmobile/frontend/shared/widgets/tutorial_overlay.dart';
import 'package:tanodmobile/models/domain/tractor_location.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showTractorShareLocationSheet(
  BuildContext context, {
  required TractorLocation tractor,
  required TractorProvider provider,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareLocationSheet(tractor: tractor, provider: provider),
  );
}

Future<void> showTractorTrackHistorySheet(
  BuildContext context, {
  required TractorLocation tractor,
  required TractorProvider provider,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TrackHistorySheet(tractor: tractor, provider: provider),
  );
}

class _ShareLocationSheet extends StatefulWidget {
  const _ShareLocationSheet({required this.tractor, required this.provider});

  final TractorLocation tractor;
  final TractorProvider provider;

  @override
  State<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<_ShareLocationSheet> {
  int _durationHours = 1;
  bool _loading = false;
  String? _shareUrl;
  String? _expiresAt;
  String? _errorMessage;

  Future<void> _generateShareLink() async {
    final deviceId = widget.tractor.deviceId;
    if (deviceId == null) {
      setState(() {
        _errorMessage =
            'This tractor does not have a linked tracker device yet.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final response = await widget.provider.createShare(
      deviceId,
      duration: _durationHours,
    );

    if (!mounted) {
      return;
    }

    final shareUrl = response?['url']?.toString();
    final expiresAt = response?['expires']?.toString();
    if (shareUrl == null || shareUrl.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to generate a share link right now.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _shareUrl = shareUrl;
      _expiresAt = expiresAt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tractor = widget.tractor;
    final imei = tractor.imei;

    return _SheetFrame(
      heightFactor: 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(onClose: () => Navigator.of(context).pop()),
          _SheetHero(
            icon: Icons.share_rounded,
            title: 'Share Location',
            subtitle: tractor.label,
            caption: imei != null && imei.trim().isNotEmpty
                ? 'IMEI $imei'
                : tractor.subtitle,
          ),
          const SizedBox(height: 20),
          const Text(
            'Link Duration',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hours in const [1, 4, 12, 24])
                _PeriodChip(
                  label: '${hours}h',
                  selected: _durationHours == hours,
                  onTap: () => setState(() => _durationHours = hours),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (_errorMessage != null)
            _InlineNotice(
              message: _errorMessage!,
              backgroundColor: AppColors.danger.withValues(alpha: 0.10),
              foregroundColor: AppColors.danger,
            ),
          if (_shareUrl == null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _generateShareLink,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pine,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(
                  _loading ? 'Generating Link...' : 'Generate Share Link',
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live share link',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _shareUrl!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Valid until ${_formatDateTimeLabel(_parseDateTime(_expiresAt))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ActionChip(
                        icon: Icons.copy_rounded,
                        label: 'Copy Link',
                        onTap: () => _copyToClipboard(
                          context,
                          value: _shareUrl!,
                          message: 'Share link copied',
                        ),
                      ),
                      _ActionChip(
                        icon: Icons.open_in_new_rounded,
                        label: 'Open Link',
                        onTap: () => _launchExternalUri(
                          context,
                          Uri.parse(_shareUrl!),
                          failureMessage: 'Unable to open the shared view.',
                        ),
                      ),
                      _ActionChip(
                        icon: Icons.refresh_rounded,
                        label: 'Regenerate',
                        onTap: () async {
                          setState(() {
                            _shareUrl = null;
                            _expiresAt = null;
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _InfoPanel(
            title: 'Live share access',
            description:
                'Anyone with this link can view the tractor\'s live position until the selected expiry window ends.',
          ),
        ],
      ),
    );
  }
}

class _TrackHistorySheet extends StatefulWidget {
  const _TrackHistorySheet({required this.tractor, required this.provider});

  final TractorLocation tractor;
  final TractorProvider provider;

  @override
  State<_TrackHistorySheet> createState() => _TrackHistorySheetState();
}

class _TrackHistorySheetState extends State<_TrackHistorySheet>
    with SingleTickerProviderStateMixin {
  _TrackHistoryPeriod _period = _TrackHistoryPeriod.today;
  bool _loading = true;
  String? _errorMessage;
  String? _warningMessage;
  List<_TrackHistoryPoint> _points = const [];
  List<LatLng> _gapMarkers = const [];
  String? _beginTime;
  String? _endTime;
  double _distanceKm = 0;
  int _movingDuration = 0;
  int _idleDuration = 0;
  int _stopCount = 0;
  int _gapCount = 0;
  int _playbackSpeed = 1;

  // ─── Smooth frame-based playback ───
  double _playbackPosition =
      0.0; // fractional index (e.g. 5.5 = between pt 5 & 6)
  late final Ticker _ticker;
  Duration? _lastTickTime;

  // Tutorial
  final _periodKey = GlobalKey();
  final _heroKey = GlobalKey();
  bool _showTutorial = false;

  bool get _isPlaying => _ticker.isActive;

  /// Points-per-millisecond rate matching web behaviour:
  ///   1× → 0.01 pts/ms (1 pt / 100ms)
  ///   2× → 0.02 pts/ms
  ///   4× → 0.04 pts/ms
  ///   8× → 0.08 pts/ms
  ///  16× → 0.16 pts/ms
  double get _pointsPerMs => _playbackSpeed / 100.0;

  /// Current segment index (integer part of _playbackPosition).
  /// Maximum valid segment = points.length - 2 (last segment connects
  /// second-to-last and last points).
  int get _segmentIndex {
    if (_points.length < 2) return 0;
    return _playbackPosition.floor().clamp(0, _points.length - 2);
  }

  /// Progress (0.0–1.0) within the current segment
  double get _segmentFraction =>
      (_playbackPosition - _segmentIndex).clamp(0.0, 1.0);

  /// Interpolated position using linear lerp between consecutive GPS points.
  /// This gives a clean, predictable path that follows the actual track.
  LatLng? get _interpolatedPosition {
    if (_points.length < 2) return null;
    final idx = _segmentIndex;
    if (idx >= _points.length - 1) {
      return LatLng(_points.last.lat, _points.last.lng);
    }
    final from = _points[idx];
    final to = _points[idx + 1];
    if (from.segment != to.segment) {
      return LatLng(from.lat, from.lng);
    }
    final f = _segmentFraction;
    return LatLng(
      from.lat + (to.lat - from.lat) * f,
      from.lng + (to.lng - from.lng) * f,
    );
  }

  /// Interpolated speed between two consecutive GPS points (linear)
  double get _interpolatedSpeed {
    if (_points.length < 2) return 0;
    final idx = _segmentIndex;
    if (idx >= _points.length - 1) return _points.last.speed;
    final from = _points[idx];
    final to = _points[idx + 1];
    if (from.segment != to.segment) return from.speed;
    return from.speed + (to.speed - from.speed) * _segmentFraction;
  }

  /// Interpolated direction between two consecutive GPS points (linear)
  double get _interpolatedDirection {
    if (_points.length < 2) return 0;
    final idx = _segmentIndex;
    if (idx >= _points.length - 1) return _points.last.direction;
    final from = _points[idx];
    final to = _points[idx + 1];
    if (from.segment != to.segment) return from.direction;
    return from.direction +
        _shortestAngle(from.direction, to.direction) * _segmentFraction;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadTrackHistory();
  }

  void _maybeShowTutorial() {
    if (!mounted || _loading || _points.isEmpty) return;

    try {
      final hive = context.read<HiveService>();
      if (!hive.tutorialsEnabled) return;
      final alreadySeen =
          hive.getPreference('tutorial_track_history') == 'true';
      if (alreadySeen) return;
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _showTutorial || _loading || _points.isEmpty) return;
      setState(() => _showTutorial = true);
    });
  }

  void _onTutorialComplete() {
    if (!mounted) return;
    try {
      context.read<HiveService>().savePreference(
        'tutorial_track_history',
        'true',
      );
    } catch (_) {}
    setState(() => _showTutorial = false);
  }

  /// Frame callback — advances playback based on elapsed real time
  void _onTick(Duration elapsed) {
    if (!mounted) {
      _ticker.stop();
      return;
    }

    final dt = _lastTickTime == null
        ? 0
        : (elapsed - _lastTickTime!).inMilliseconds;
    _lastTickTime = elapsed;

    // Ignore huge gaps (e.g. after app suspend) to avoid jumping wildly
    if (dt <= 0 || dt > 2000) return;

    final pointsToAdvance = dt * _pointsPerMs;

    if (pointsToAdvance > 0) {
      final newPosition = (_playbackPosition + pointsToAdvance).clamp(
        0.0,
        (_points.length - 1).toDouble(),
      );

      if (newPosition >= _points.length - 1) {
        _playbackPosition = newPosition;
        setState(() {});
        _stopPlayback();
        return;
      }

      setState(() {
        _playbackPosition = newPosition;
      });
    }
  }

  /// Returns the shortest signed angle from [a] to [b] (handles 0°/360° wrap)
  static double _shortestAngle(double a, double b) {
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadTrackHistory() async {
    final deviceId = widget.tractor.deviceId;
    if (deviceId == null) {
      setState(() {
        _loading = false;
        _errorMessage =
            'This tractor does not have a linked tracker device yet.';
      });
      return;
    }

    _stopPlayback();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _warningMessage = null;
    });

    final response = await widget.provider.fetchTrackData(
      deviceId,
      _period.apiValue,
    );
    if (!mounted) {
      return;
    }

    final rawPoints = response?['points'] as List<dynamic>?;
    final warnings = response?['warnings'] as List<dynamic>? ?? const [];
    final firstWarning = warnings.isNotEmpty && warnings.first is Map
        ? (warnings.first as Map)['message']?.toString()
        : null;
    if (response == null || rawPoints == null || response['success'] == false) {
      setState(() {
        _loading = false;
        _errorMessage =
            firstWarning ?? 'Unable to load track history right now.';
      });
      return;
    }

    final parsedPoints = rawPoints
        .whereType<Map<String, dynamic>>()
        .map(_TrackHistoryPoint.fromJson)
        .toList(growable: false);
    final track = response['track'] as Map<String, dynamic>?;
    final rawGaps = track?['gaps'] as List<dynamic>? ?? const [];
    final gapMarkers = rawGaps
        .whereType<Map<String, dynamic>>()
        .map((gap) {
          final lat = (gap['marker_lat'] as num?)?.toDouble();
          final lng = (gap['marker_lng'] as num?)?.toDouble();
          return lat != null && lng != null ? LatLng(lat, lng) : null;
        })
        .whereType<LatLng>()
        .toList(growable: false);

    setState(() {
      _loading = false;
      _beginTime = (response['begin_time_local'] ?? response['begin_time'])
          ?.toString();
      _endTime = (response['end_time_local'] ?? response['end_time'])
          ?.toString();
      _warningMessage = response['partial'] == true
          ? '${warnings.length} JIMI time range could not be loaded.'
          : null;
      _points = parsedPoints;
      _gapMarkers = gapMarkers;
      _distanceKm = (track?['distance_km'] as num?)?.toDouble() ?? 0;
      _movingDuration = (track?['moving_duration'] as num?)?.toInt() ?? 0;
      _idleDuration = (track?['idle_duration'] as num?)?.toInt() ?? 0;
      _stopCount = (track?['stop_count'] as num?)?.toInt() ?? 0;
      _gapCount = (track?['gap_count'] as num?)?.toInt() ?? 0;
      _playbackPosition = 0.0;
      _lastTickTime = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
      return;
    }

    _startPlayback();
  }

  void _startPlayback() {
    if (_points.length < 2) {
      return;
    }

    if (_playbackPosition >= _points.length - 1) {
      _playbackPosition = 0.0;
    }

    _lastTickTime = null;
    _ticker.start();
    setState(() {});
  }

  void _stopPlayback() {
    _ticker.stop();
    _lastTickTime = null;

    if (mounted) {
      setState(() {});
    }
  }

  void _resetPlayback() {
    _ticker.stop();
    setState(() {
      _playbackPosition = 0.0;
      _lastTickTime = null;
    });
  }

  void _seekTo(double nextValue) {
    if (_points.isEmpty) {
      return;
    }

    _ticker.stop();
    setState(() {
      _playbackPosition = nextValue.clamp(0.0, (_points.length - 1).toDouble());
      _lastTickTime = null;
    });
  }

  void _stepBy(int offset) {
    if (_points.isEmpty) {
      return;
    }

    _ticker.stop();
    setState(() {
      _playbackPosition = (_playbackPosition + offset).clamp(
        0.0,
        (_points.length - 1).toDouble(),
      );
      _lastTickTime = null;
    });
  }

  void _setPlaybackSpeed(int speed) {
    if (_playbackSpeed == speed) {
      return;
    }

    final wasPlaying = _isPlaying;
    _ticker.stop();
    setState(() {
      _playbackSpeed = speed;
      _lastTickTime = null;
    });

    if (wasPlaying) {
      _startPlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstPoint = _points.isNotEmpty ? _points.first : null;
    final lastPoint = _points.isNotEmpty ? _points.last : null;
    final maxSpeed = _points.fold<double>(
      0,
      (current, point) => point.speed > current ? point.speed : current,
    );
    final duration =
        firstPoint?.recordedAt != null && lastPoint?.recordedAt != null
        ? lastPoint!.recordedAt!.difference(firstPoint!.recordedAt!)
        : null;
    final playbackIndex = _points.isEmpty
        ? 0
        : _playbackPosition.floor().clamp(0, _points.length - 1);
    final currentPoint = _points.isNotEmpty ? _points[playbackIndex] : null;
    final trailPoints = _points
        .map((point) => LatLng(point.lat, point.lng))
        .toList(growable: false);
    final trailSegmentIds = _points
        .map((point) => point.segment)
        .toList(growable: false);
    final interpolatedPos = _interpolatedPosition;
    final interpSpeed = _interpolatedSpeed;
    final interpDirection = _interpolatedDirection;

    return _SheetFrame(
      heightFactor: 0.94,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(onClose: () => Navigator.of(context).pop()),
              _SheetHero(
                key: _heroKey,
                icon: Icons.route_rounded,
                title: 'Track History',
                subtitle: widget.tractor.label,
                caption: widget.tractor.subtitle,
              ),
              const SizedBox(height: 20),
              Wrap(
                key: _periodKey,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final period in _TrackHistoryPeriod.values)
                    _PeriodChip(
                      label: period.label,
                      selected: _period == period,
                      onTap: _loading && _period == period
                          ? null
                          : () {
                              if (_period == period) {
                                return;
                              }
                              setState(() => _period = period);
                              _loadTrackHistory();
                            },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.pine),
                      )
                    : _errorMessage != null
                    ? _ErrorState(
                        message: _errorMessage!,
                        onRetry: _loadTrackHistory,
                      )
                    : _points.isEmpty
                    ? _EmptyState(
                        icon: Icons.alt_route_rounded,
                        title: 'No track points found',
                        message:
                            'There are no recorded GPS points for the selected time range yet.',
                        actionLabel: 'Reload',
                        onTap: _loadTrackHistory,
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_warningMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _warningMessage!,
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            SizedBox(
                              height: 240,
                              child: TractorTrackHistoryMap(
                                trailPoints: trailPoints,
                                segmentIds: trailSegmentIds,
                                gapMarkers: _gapMarkers,
                                playbackIndex: playbackIndex,
                                interpolatedPosition: interpolatedPos,
                                currentSpeed: interpSpeed,
                                currentDirection: interpDirection,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Points',
                                    value: '${_points.length}',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Top Speed',
                                    value:
                                        '${maxSpeed.toStringAsFixed(1)} km/h',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Window',
                                    value: _formatDurationLabel(duration),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Distance',
                                    value:
                                        '${_distanceKm.toStringAsFixed(1)} km',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Stops',
                                    value: '$_stopCount',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Gaps / Spikes',
                                    value: '$_gapCount',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Moving',
                                    value: _formatDurationLabel(
                                      Duration(seconds: _movingDuration),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Idle',
                                    value: _formatDurationLabel(
                                      Duration(seconds: _idleDuration),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Playback',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.mutedInk,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDateTimeLabel(
                                                currentPoint?.recordedAt,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _SmallPill(
                                        label:
                                            '${(_playbackPosition + 1).toStringAsFixed(1)}/${_points.length}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppColors.pine,
                                      inactiveTrackColor: AppColors.pine
                                          .withValues(alpha: 0.12),
                                      thumbColor: AppColors.pine,
                                      overlayColor: AppColors.pine.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    child: Slider(
                                      value: _playbackPosition,
                                      min: 0,
                                      max: (_points.length - 1).toDouble(),
                                      onChanged: _points.length > 1
                                          ? _seekTo
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _PlaybackButton(
                                        icon: Icons.restart_alt_rounded,
                                        onTap: _resetPlayback,
                                      ),
                                      const SizedBox(width: 8),
                                      _PlaybackButton(
                                        icon: Icons.skip_previous_rounded,
                                        onTap: playbackIndex > 0
                                            ? () => _stepBy(-1)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _points.length > 1
                                              ? _togglePlayback
                                              : null,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.pine,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          icon: Icon(
                                            _isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                          ),
                                          label: Text(
                                            _isPlaying
                                                ? 'Pause Playback'
                                                : 'Play Playback',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _PlaybackButton(
                                        icon: Icons.skip_next_rounded,
                                        onTap:
                                            playbackIndex < _points.length - 1
                                            ? () => _stepBy(1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final speed in const [
                                        1,
                                        2,
                                        4,
                                        8,
                                        16,
                                      ])
                                        _PlaybackSpeedChip(
                                          label: '${speed}x',
                                          selected: _playbackSpeed == speed,
                                          onTap: () => _setPlaybackSpeed(speed),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SummaryLine(
                                    label: 'Start',
                                    value: _formatDateTimeLabel(
                                      firstPoint?.recordedAt,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryLine(
                                    label: 'Current',
                                    value: interpolatedPos == null
                                        ? 'Unavailable'
                                        : '${interpolatedPos.latitude.toStringAsFixed(5)}, ${interpolatedPos.longitude.toStringAsFixed(5)} at ${interpSpeed.toStringAsFixed(1)} km/h',
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryLine(
                                    label: 'End',
                                    value: _formatDateTimeLabel(
                                      lastPoint?.recordedAt,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryLine(
                                    label: 'Server Range',
                                    value:
                                        '${_formatDateTimeLabel(_parseDateTime(_beginTime))} to ${_formatDateTimeLabel(_parseDateTime(_endTime))}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'GPS Timeline',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Highlighted point follows playback',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mutedInk.withValues(
                                      alpha: 0.90,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 260,
                              child: ListView.separated(
                                itemCount: _points.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final pointIndex = _points.length - 1 - index;
                                  final point = _points[pointIndex];
                                  return _TrackPointTile(
                                    point: point,
                                    isActive: pointIndex == playbackIndex,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
              ),
            ],
          ),

          // ─── Tutorial overlay ───
          if (_showTutorial)
            TutorialOverlayWidget(
              steps: [
                TutorialStep(
                  targetKey: _heroKey,
                  title: 'Track History Playback',
                  description:
                      'This timeline shows the tractor\'s route and stops '
                      'for a selected time range. Choose a period above, '
                      'then use the playback controls below the map to '
                      'watch the tractor retrace its path. You can adjust '
                      'the playback speed with the 1x–16x buttons.',
                  tooltipPosition: TutorialTooltipPosition.bottom,
                ),
              ],
              onComplete: _onTutorialComplete,
              onSkip: _onTutorialComplete,
            ),
        ], // ← closes Stack children
      ), // ← closes Stack
    ); // ← closes _SheetFrame child
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.heightFactor, required this.child});

  final double heightFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.canvas,
            foregroundColor: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _SheetHero extends StatelessWidget {
  const _SheetHero({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.pine.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AppColors.pine, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.pine : AppColors.canvas,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.pine),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pine.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedInk,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackPointTile extends StatelessWidget {
  const _TrackPointTile({required this.point, this.isActive = false});

  final _TrackHistoryPoint point;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.pine.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.pine.withValues(alpha: 0.28)
              : AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.pine.withValues(alpha: 0.16)
                  : AppColors.pine.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 18,
              color: isActive ? AppColors.pine : AppColors.pine,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTimeLabel(point.recordedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isActive) const _SmallPill(label: 'Playback point'),
                    if (isActive) const SizedBox(width: 8),
                    _SmallPill(label: '${point.speed.toStringAsFixed(1)} km/h'),
                    _SmallPill(
                      label: '${point.direction.toStringAsFixed(0)} deg',
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedInk,
        ),
      ),
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.mutedInk : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _PlaybackSpeedChip extends StatelessWidget {
  const _PlaybackSpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.pine : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 34,
            color: AppColors.danger,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.mutedInk),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: AppColors.mutedInk),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => onTap!(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

enum _TrackHistoryPeriod {
  today('today', 'Today'),
  yesterday('yesterday', 'Yesterday'),
  threeDays('3days', '3 Days'),
  week('week', 'Week'),
  month('month', 'Month');

  const _TrackHistoryPeriod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class _TrackHistoryPoint {
  const _TrackHistoryPoint({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.direction,
    required this.recordedAt,
    required this.segment,
  });

  final double lat;
  final double lng;
  final double speed;
  final double direction;
  final DateTime? recordedAt;
  final int segment;

  factory _TrackHistoryPoint.fromJson(Map<String, dynamic> json) {
    return _TrackHistoryPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      direction: (json['direction'] as num?)?.toDouble() ?? 0,
      recordedAt: _parseDateTime(json['gps_time']?.toString()),
      segment: (json['segment'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _parseDateTime(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(rawValue);
  if (parsed == null) {
    return null;
  }

  return parsed.isUtc ? parsed.toLocal() : parsed;
}

String _formatDateTimeLabel(DateTime? value) {
  if (value == null) {
    return 'Unavailable';
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour >= 12 ? 'PM' : 'AM';
  return '${months[value.month - 1]} ${value.day}, ${value.year} $hour:$minute $meridiem';
}

String _formatDurationLabel(Duration? duration) {
  if (duration == null || duration.inSeconds <= 0) {
    return 'Single ping';
  }

  if (duration.inDays >= 1) {
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  }
  if (duration.inHours >= 1) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes >= 1) {
    return '${duration.inMinutes}m';
  }
  return '${duration.inSeconds}s';
}

Future<void> _copyToClipboard(
  BuildContext context, {
  required String value,
  required String message,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }

  _showSheetFeedback(context, message, backgroundColor: AppColors.success);
}

Future<void> _launchExternalUri(
  BuildContext context,
  Uri uri, {
  required String failureMessage,
}) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) {
    return;
  }

  if (!launched) {
    _showSheetFeedback(
      context,
      failureMessage,
      backgroundColor: AppColors.danger,
    );
  }
}

void _showSheetFeedback(
  BuildContext context,
  String message, {
  required Color backgroundColor,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
    ),
  );
}
