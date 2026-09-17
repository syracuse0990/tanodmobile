import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/utils/geo_area.dart';

/// Live "how big is this zone" readout shown under the drawing map.
///
/// Shows the total area (hectares by default) plus the boundary length for
/// both circle and polygon shapes.
class GeofenceAreaSummary extends StatelessWidget {
  const GeofenceAreaSummary({
    super.key,
    required this.areaSquareMeters,
    this.boundaryMeters,
    this.areaCaption = 'Total area',
    this.boundaryCaption = 'Perimeter',
    this.emptyHint,
  });

  final double? areaSquareMeters;
  final double? boundaryMeters;
  final String areaCaption;
  final String boundaryCaption;
  final String? emptyHint;

  bool get _hasArea => areaSquareMeters != null && areaSquareMeters! > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.forest.withValues(alpha: 0.18)),
      ),
      child: _hasArea
          ? Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons.square_foot_rounded,
                    value: GeoArea.areaLabel(areaSquareMeters!),
                    caption: areaCaption,
                    highlight: true,
                  ),
                ),
                if (boundaryMeters != null && boundaryMeters! > 0) ...[
                  Container(
                    width: 1,
                    height: 34,
                    color: AppColors.ink.withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Metric(
                      icon: Icons.straighten_rounded,
                      value: GeoArea.lengthLabel(boundaryMeters!),
                      caption: boundaryCaption,
                    ),
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.square_foot_rounded,
                  size: 18,
                  color: AppColors.mutedInk.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    emptyHint ?? 'Draw a shape on the map to measure its area.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.caption,
    this.highlight = false,
  });

  final IconData icon;
  final String value;
  final String caption;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: highlight ? AppColors.forest : AppColors.mutedInk,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppColors.forest : AppColors.ink,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small floating pill used as a map marker to show a zone's area
/// (e.g. `12.35 ha`). Never steals map gestures.
class MapAreaBadge extends StatelessWidget {
  const MapAreaBadge({
    super.key,
    required this.label,
    this.icon = Icons.square_foot_rounded,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.forest.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: AppColors.forest),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
