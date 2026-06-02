import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/models/domain/tps_fca.dart';

class FcaExistingFcaSuggestions extends StatelessWidget {
  const FcaExistingFcaSuggestions({
    super.key,
    required this.query,
    required this.suggestions,
    required this.isLoading,
    required this.onSelected,
  });

  final String query;
  final List<TpsFca> suggestions;
  final bool isLoading;
  final ValueChanged<TpsFca> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              'Existing FCA suggestions',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: AppColors.forest.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Searching existing FCA records...',
                      style: TextStyle(fontSize: 12, color: AppColors.mutedInk),
                    ),
                  ),
                ],
              ),
            )
          else if (suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Text(
                'No existing FCA found for "$query". You can continue creating a new one.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.mutedInk,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                final title = _displayLabel(suggestion);
                final detailParts =
                    [
                          suggestion.fullName,
                          suggestion.contactLabel,
                          suggestion.locationLabel,
                        ]
                        .where((value) => value.trim().isNotEmpty)
                        .toList(growable: false);

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => onSelected(suggestion),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.ink.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.forest.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: AppColors.forest,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (detailParts.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    detailParts.join(' • '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.35,
                                      color: AppColors.mutedInk,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.north_west_rounded,
                            size: 18,
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

String _displayLabel(TpsFca fca) {
  final organizationName = fca.organizationName?.trim();
  if (organizationName != null && organizationName.isNotEmpty) {
    return organizationName;
  }

  return fca.name.trim().isNotEmpty ? fca.name.trim() : 'Existing FCA';
}
