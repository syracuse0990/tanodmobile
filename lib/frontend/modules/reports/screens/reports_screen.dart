import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/report_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportProvider>().fetchReports();
  }

  Future<void> _onRefresh() async {
    await context.read<ReportProvider>().fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account'),
        ),
      ),
      body: provider.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest))
          : provider.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48,
                          color: AppColors.mutedInk.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(provider.error!,
                          style: const TextStyle(color: AppColors.mutedInk)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _onRefresh,
                        child: const Text('Retry',
                            style: TextStyle(color: AppColors.forest)),
                      ),
                    ],
                  ),
                )
              : provider.sections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assessment_outlined,
                              size: 56,
                              color:
                                  AppColors.mutedInk.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'No reports available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: provider.sections.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _ReportCard(
                              section: provider.sections[index]);
                        },
                      ),
                    ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.section});

  final ReportSection section;

  IconData get _icon => switch (section.icon) {
        'people' => Icons.people_outline_rounded,
        'calendar' => Icons.calendar_month_rounded,
        'tractor' => Icons.agriculture_rounded,
        'build' => Icons.build_outlined,
        'star' => Icons.star_outline_rounded,
        _ => Icons.assessment_outlined,
      };

  Color get _accentColor => switch (section.icon) {
        'people' => AppColors.pine,
        'calendar' => AppColors.forest,
        'tractor' => AppColors.gold,
        'build' => AppColors.clay,
        'star' => AppColors.gold,
        _ => AppColors.forest,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Header ───
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: _accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Rows ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                for (var i = 0; i < section.rows.length; i++) ...[
                  _DataRow(
                    row: section.rows[i],
                    isHighlighted: i == 0,
                  ),
                  if (i < section.rows.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.ink.withValues(alpha: 0.04),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.row, this.isHighlighted = false});

  final ReportRow row;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: isHighlighted ? AppColors.ink : AppColors.mutedInk,
              ),
            ),
          ),
          Text(
            _formatValue(row.value),
            style: TextStyle(
              fontSize: isHighlighted ? 18 : 15,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppColors.forest : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(String raw) {
    final number = double.tryParse(raw);
    if (number == null) return raw;

    // Format with commas for large numbers
    if (number == number.roundToDouble() && number >= 1000) {
      return _addCommas(number.toInt().toString());
    }
    if (number >= 1000) {
      return _addCommas(number.toStringAsFixed(1));
    }

    // Show decimals only when meaningful
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(1);
  }

  String _addCommas(String value) {
    final parts = value.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    if (parts.length > 1) {
      buffer.write('.${parts[1]}');
    }
    return buffer.toString();
  }
}
