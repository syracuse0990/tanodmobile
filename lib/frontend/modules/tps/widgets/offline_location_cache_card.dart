import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/models/local/offline_location_cache_summary.dart';

class OfflineLocationCacheCard extends StatelessWidget {
  const OfflineLocationCacheCard({
    super.key,
    required this.summary,
    this.showProvinceBreakdown = false,
  });

  final OfflineLocationCacheSummary summary;
  final bool showProvinceBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Downloaded location data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.hasData
                ? 'Province, city, and barangay lists already saved on this phone for offline revisit forms.'
                : 'Update data first so this phone can save the province, city, and barangay lists used by offline revisit forms.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedInk,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LocationCountChip(
                icon: Icons.map_rounded,
                label: _formatCount(
                  summary.provinceCount,
                  singular: 'province',
                  plural: 'provinces',
                ),
                color: AppColors.forest,
              ),
              _LocationCountChip(
                icon: Icons.location_city_rounded,
                label: _formatCount(
                  summary.cityCount,
                  singular: 'city',
                  plural: 'cities',
                ),
                color: AppColors.clay,
              ),
              _LocationCountChip(
                icon: Icons.place_rounded,
                label: _formatCount(
                  summary.barangayCount,
                  singular: 'barangay',
                  plural: 'barangays',
                ),
                color: AppColors.pine,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!summary.hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No location data downloaded yet.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedInk,
                ),
              ),
            )
          else if (showProvinceBreakdown) ...[
            const Text(
              'Saved provinces',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            ...summary.provinces.map(
              (province) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProvinceLocationTile(province: province),
              ),
            ),
          ] else
            Text(
              _buildProvincePreview(summary),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }

  String _buildProvincePreview(OfflineLocationCacheSummary summary) {
    final previewNames = summary.provinces
        .take(3)
        .map((province) => province.name)
        .toList(growable: false);
    final remainingCount = summary.provinceCount - previewNames.length;

    if (previewNames.isEmpty) {
      return 'No provinces saved yet.';
    }

    final preview = previewNames.join(', ');
    if (remainingCount <= 0) {
      return 'Saved provinces: $preview.';
    }

    return 'Saved provinces include $preview, and $remainingCount more.';
  }
}

class _ProvinceLocationTile extends StatelessWidget {
  const _ProvinceLocationTile({required this.province});

  final OfflineLocationProvinceSummary province;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.forest,
          collapsedIconColor: AppColors.mutedInk,
          title: Text(
            province.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            '${_formatCount(province.cityCount, singular: 'city', plural: 'cities')} • ${_formatCount(province.barangayCount, singular: 'barangay', plural: 'barangays')}',
            style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
          ),
          children: [
            if (province.cities.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No city data saved yet.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedInk,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final city in province.cities)
                    _CityLocationChip(
                      label:
                          '${city.name} (${_formatCount(city.barangayCount, singular: 'barangay', plural: 'barangays')})',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationCountChip extends StatelessWidget {
  const _LocationCountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityLocationChip extends StatelessWidget {
  const _CityLocationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

String _formatCount(
  int count, {
  required String singular,
  required String plural,
}) {
  final label = count == 1 ? singular : plural;
  return '$count $label';
}
