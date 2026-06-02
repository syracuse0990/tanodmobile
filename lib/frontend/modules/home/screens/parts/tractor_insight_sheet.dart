import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/models/domain/pms_record.dart';
import 'package:tanodmobile/models/domain/tractor_insight_detail.dart';
import 'package:tanodmobile/models/domain/tractor_location.dart';
import 'package:url_launcher/url_launcher.dart';

enum TractorInsightTab {
  fcaDetails,
  pmsHistory,
}

Future<void> showTractorInsightSheet(
  BuildContext context, {
  required TractorLocation tractor,
  required TractorInsightTab initialTab,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TractorInsightSheet(
      tractor: tractor,
      initialTab: initialTab,
    ),
  );
}

class _TractorInsightSheet extends StatefulWidget {
  const _TractorInsightSheet({
    required this.tractor,
    required this.initialTab,
  });

  final TractorLocation tractor;
  final TractorInsightTab initialTab;

  @override
  State<_TractorInsightSheet> createState() => _TractorInsightSheetState();
}

class _TractorInsightSheetState extends State<_TractorInsightSheet>
    with SingleTickerProviderStateMixin {
  late final ApiClient _apiClient;
  late final TabController _tabController;
  late Future<_TractorInsightBundle> _insightFuture;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _tabController = TabController(
      length: TractorInsightTab.values.length,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _insightFuture = _loadInsight();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_TractorInsightBundle> _loadInsight() async {
    final responses = await Future.wait([
      _apiClient.get('${AppEndpoints.tractors}/${widget.tractor.id}'),
      _apiClient.get(
        AppEndpoints.maintenances,
        queryParameters: {
          'tractor_id': '${widget.tractor.id}',
          'per_page': '50',
        },
      ),
    ]);

    final detailBody = responses[0]['data'];
    if (detailBody is! Map<String, dynamic>) {
      throw StateError('Unable to load tractor details.');
    }

    final recordList = responses[1]['data'] as List<dynamic>? ?? [];
    final records = recordList
        .whereType<Map<String, dynamic>>()
        .map(PmsRecord.fromJson)
        .toList(growable: false);

    return _TractorInsightBundle(
      detail: TractorInsightDetail.fromJson(detailBody),
      records: records,
    );
  }

  void _retry() {
    setState(() {
      _insightFuture = _loadInsight();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F5F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tractor.label,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Fleet insights',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.pine,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.mutedInk,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(6),
                    tabs: const [
                      Tab(text: 'FCA Details'),
                      Tab(text: 'PMS History'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<_TractorInsightBundle>(
                  future: _insightFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _InsightLoadingState();
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return _InsightErrorState(onRetry: _retry);
                    }

                    final bundle = snapshot.data!;

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _FcaDetailsTab(
                          tractor: widget.tractor,
                          detail: bundle.detail,
                          latestCompletedRecord: bundle.latestCompletedRecord,
                        ),
                        _PmsHistoryTab(
                          tractor: widget.tractor,
                          detail: bundle.detail,
                          records: bundle.records,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TractorInsightBundle {
  const _TractorInsightBundle({
    required this.detail,
    required this.records,
  });

  final TractorInsightDetail detail;
  final List<PmsRecord> records;

  PmsRecord? get latestCompletedRecord {
    for (final record in records) {
      if (record.isCompleted) {
        return record;
      }
    }

    return null;
  }
}

class _FcaDetailsTab extends StatelessWidget {
  const _FcaDetailsTab({
    required this.tractor,
    required this.detail,
    required this.latestCompletedRecord,
  });

  final TractorLocation tractor;
  final TractorInsightDetail detail;
  final PmsRecord? latestCompletedRecord;

  @override
  Widget build(BuildContext context) {
    final contact = detail.fca;
    final imeiValue = detail.imei ?? tractor.imei ?? 'Unavailable';
    final tractorBrand = detail.brand ?? 'Unavailable';
    final tractorModel = detail.model ?? 'Unavailable';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightHero(tractor: tractor, detail: detail),
          const SizedBox(height: 20),
          const _SectionHeading(
            title: 'FCA Details',
            subtitle: 'Assigned contact for this tractor',
          ),
          _SectionCard(
            child: contact == null || contact.isEmpty
                ? const _EmptySectionMessage(
                    icon: Icons.person_off_rounded,
                    message: 'No FCA details are assigned to this tractor yet.',
                  )
                : Column(
                    children: [
                      _DetailLine(
                        icon: Icons.person_outline_rounded,
                        label: 'FCA Name',
                        value: contact.name ?? 'Unavailable',
                      ),
                      const _SectionDivider(),
                      _ActionableDetailLine(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: contact.email ?? 'Unavailable',
                        actions: [
                          if (contact.email != null)
                            _InlineActionData(
                              icon: Icons.alternate_email_rounded,
                              label: 'Email',
                              onTap: () => _launchExternalUri(
                                context,
                                Uri(
                                  scheme: 'mailto',
                                  path: contact.email!,
                                ),
                                failureMessage: 'Unable to open email app.',
                              ),
                            ),
                          if (contact.email != null)
                            _InlineActionData(
                              icon: Icons.copy_rounded,
                              label: 'Copy',
                              onTap: () => _copyValue(
                                context,
                                value: contact.email!,
                                label: 'Email copied',
                              ),
                            ),
                        ],
                      ),
                      const _SectionDivider(),
                      _ActionableDetailLine(
                        icon: Icons.phone_outlined,
                        label: 'Mobile Number',
                        value: contact.phone ?? 'Unavailable',
                        actions: [
                          if (contact.phone != null)
                            _InlineActionData(
                              icon: Icons.call_rounded,
                              label: 'Call',
                              onTap: () => _launchExternalUri(
                                context,
                                Uri(
                                  scheme: 'tel',
                                  path: contact.phone!,
                                ),
                                failureMessage: 'Unable to open phone app.',
                              ),
                            ),
                          if (contact.phone != null)
                            _InlineActionData(
                              icon: Icons.sms_rounded,
                              label: 'Text',
                              onTap: () => _launchExternalUri(
                                context,
                                Uri(
                                  scheme: 'sms',
                                  path: contact.phone!,
                                ),
                                failureMessage: 'Unable to open messaging app.',
                              ),
                            ),
                          if (contact.phone != null)
                            _InlineActionData(
                              icon: Icons.copy_rounded,
                              label: 'Copy',
                              onTap: () => _copyValue(
                                context,
                                value: contact.phone!,
                                label: 'Mobile number copied',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          const _SectionHeading(
            title: 'Tractor Details',
            subtitle: 'Operational and preventive maintenance snapshot',
          ),
          _MetricGrid(
            tiles: [
              _MetricTileData(
                label: 'Total Distance',
                value: _formatDistance(detail.totalDistance),
                icon: Icons.route_rounded,
                accent: AppColors.pine,
              ),
              _MetricTileData(
                label: 'Running Hours',
                value: _formatHours(detail.totalRunningHours),
                icon: Icons.timer_outlined,
                accent: AppColors.gold,
              ),
              _MetricTileData(
                label: 'PMS Status',
                value: detail.pmsStatusLabel,
                icon: Icons.health_and_safety_outlined,
                accent: _pmsStatusColor(detail.pmsStatus),
              ),
              _MetricTileData(
                label: 'Last PMS',
                value: _formatLastPms(latestCompletedRecord),
                icon: Icons.event_note_rounded,
                accent: AppColors.moss,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              children: [
                _DetailLine(
                  icon: Icons.numbers_rounded,
                  label: 'IMEI Number',
                  value: imeiValue,
                ),
                _SectionDivider(),
                _DetailLine(
                  icon: Icons.precision_manufacturing_outlined,
                  label: 'Tractor Brand',
                  value: tractorBrand,
                ),
                _SectionDivider(),
                _DetailLine(
                  icon: Icons.category_outlined,
                  label: 'Model',
                  value: tractorModel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PmsHistoryTab extends StatelessWidget {
  const _PmsHistoryTab({
    required this.tractor,
    required this.detail,
    required this.records,
  });

  final TractorLocation tractor;
  final TractorInsightDetail detail;
  final List<PmsRecord> records;

  @override
  Widget build(BuildContext context) {
    final completedCount = records.where((record) => record.isCompleted).length;
    final scheduledCount = records.where((record) => record.isScheduled).length;

    if (records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          _InsightHero(tractor: tractor, detail: detail),
          const SizedBox(height: 20),
          const _SectionHeading(
            title: 'PMS History',
            subtitle: 'Service records tied to this tractor',
          ),
          const _SectionCard(
            child: _EmptySectionMessage(
              icon: Icons.history_toggle_off_rounded,
              message: 'No PMS history is available for this tractor yet.',
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        _InsightHero(tractor: tractor, detail: detail),
        const SizedBox(height: 20),
        const _SectionHeading(
          title: 'PMS History',
          subtitle: 'Recent maintenance events, notes, and checklist outcomes',
        ),
        _HistorySummaryCard(
          totalCount: records.length,
          completedCount: completedCount,
          scheduledCount: scheduledCount,
        ),
        const SizedBox(height: 16),
        for (int index = 0; index < records.length; index++) ...[
          _PmsHistoryCard(
            record: records[index],
            initiallyExpanded: index == 0,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _InsightHero extends StatelessWidget {
  const _InsightHero({
    required this.tractor,
    required this.detail,
  });

  final TractorLocation tractor;
  final TractorInsightDetail detail;

  @override
  Widget build(BuildContext context) {
    final assetPath = _tractorAssetForState(
      isOnline: tractor.isOnline,
      isIdle: tractor.isIdle,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.pine],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
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
              children: [
                Text(
                  detail.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.brandLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(
                      icon: Icons.sensors_rounded,
                      label: tractor.statusLabel,
                    ),
                    _HeroPill(
                      icon: Icons.access_time_rounded,
                      label: '${tractor.isOnline ? 'Last update' : 'Last online'} ${tractor.lastOnlineLabel}',
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

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({
    required this.totalCount,
    required this.completedCount,
    required this.scheduledCount,
  });

  final int totalCount;
  final int completedCount;
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _HistorySummaryTile(
              label: 'Records',
              value: '$totalCount',
              accent: AppColors.pine,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HistorySummaryTile(
              label: 'Completed',
              value: '$completedCount',
              accent: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HistorySummaryTile(
              label: 'Pending',
              value: '$scheduledCount',
              accent: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySummaryTile extends StatelessWidget {
  const _HistorySummaryTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _PmsHistoryCard extends StatefulWidget {
  const _PmsHistoryCard({
    required this.record,
    this.initiallyExpanded = false,
  });

  final PmsRecord record;
  final bool initiallyExpanded;

  @override
  State<_PmsHistoryCard> createState() => _PmsHistoryCardState();
}

class _PmsHistoryCardState extends State<_PmsHistoryCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final statusInfo = _statusInfo(record.status);
    final doneCount = record.checklist.where((item) => item.done).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.background,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusInfo.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusInfo.foreground,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(record.maintenanceDate ?? record.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CompactChip(
                        icon: Icons.schedule_rounded,
                        label: _formatHours(record.hoursAtMaintenance),
                      ),
                      _CompactChip(
                        icon: Icons.route_rounded,
                        label: _formatDistance(record.kmAtMaintenance),
                      ),
                      if (record.checklist.isNotEmpty)
                        _CompactChip(
                          icon: Icons.checklist_rounded,
                          label:
                              '$doneCount/${record.checklist.length} checklist items',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _historyPreview(record),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedInk,
                    ),
                    maxLines: _expanded ? null : 2,
                    overflow:
                        _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        _expanded ? 'Hide full details' : 'Tap to view full details',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pine,
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.pine,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionDivider(),
                  if (record.creator != null)
                    _DetailLine(
                      icon: Icons.person_outline_rounded,
                      label: 'Recorded By',
                      value: record.creator!.name ?? 'Unknown',
                    ),
                  if (record.requester != null) ...[
                    const SizedBox(height: 10),
                    _DetailLine(
                      icon: Icons.support_agent_rounded,
                      label: 'Requested By',
                      value: record.requester!.name ?? 'Unknown',
                    ),
                  ],
                  if (record.performer != null) ...[
                    const SizedBox(height: 10),
                    _DetailLine(
                      icon: Icons.engineering_rounded,
                      label: 'Performed By',
                      value: record.performer!.name ?? 'Unknown',
                    ),
                  ],
                  if (_hasNarrative(record)) ...[
                    const SizedBox(height: 14),
                    if (record.requestNotes != null &&
                        record.requestNotes!.isNotEmpty)
                      _NarrativeCard(
                        label: 'Request Notes',
                        value: record.requestNotes!,
                        accent: AppColors.warning,
                      ),
                    if (record.description != null &&
                        record.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _NarrativeCard(
                        label: 'Description',
                        value: record.description!,
                        accent: AppColors.pine,
                      ),
                    ],
                    if (record.conclusion != null &&
                        record.conclusion!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _NarrativeCard(
                        label: 'Conclusion',
                        value: record.conclusion!,
                        accent: AppColors.success,
                      ),
                    ],
                  ],
                  if (record.checklist.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Checklist',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7F5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          for (int index = 0;
                              index < record.checklist.length;
                              index++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    record.checklist[index].done
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: record.checklist[index].done
                                        ? AppColors.success
                                        : AppColors.mutedInk,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record.checklist[index].name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        if (record.checklist[index].notes !=
                                                null &&
                                            record.checklist[index].notes!
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            record.checklist[index].notes!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.mutedInk,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index != record.checklist.length - 1)
                              const _SectionDivider(),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (record.images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: record.images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final image = record.images[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              image.url,
                              width: 96,
                              height: 84,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stackTrace) => Container(
                                width: 96,
                                height: 84,
                                color: AppColors.canvas,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  bool _hasNarrative(PmsRecord record) {
    return (record.requestNotes != null && record.requestNotes!.isNotEmpty) ||
        (record.description != null && record.description!.isNotEmpty) ||
        (record.conclusion != null && record.conclusion!.isNotEmpty);
  }
}

String _historyPreview(PmsRecord record) {
  final actor = record.performer?.name ??
      record.creator?.name ??
      record.requester?.name;

  if (actor != null && actor.isNotEmpty) {
    return 'Lead contact: $actor';
  }

  if (record.requestNotes != null && record.requestNotes!.isNotEmpty) {
    return record.requestNotes!;
  }

  if (record.description != null && record.description!.isNotEmpty) {
    return record.description!;
  }

  return 'Checklist, notes, and photos are available inside this record.';
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.tiles});

  final List<_MetricTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: _MetricTile(tile: tile),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTileData {
  const _MetricTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.tile});

  final _MetricTileData tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tile.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tile.icon, color: tile.accent, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            tile.value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tile.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.pine),
          const SizedBox(width: 6),
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
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.pine),
        ),
        const SizedBox(width: 12),
        Expanded(
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
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionableDetailLine extends StatelessWidget {
  const _ActionableDetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.actions = const [],
  });

  final IconData icon;
  final String label;
  final String value;
  final List<_InlineActionData> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.pine),
        ),
        const SizedBox(width: 12),
        Expanded(
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
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in actions)
                      _InlineActionButton(action: action),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineActionData {
  const _InlineActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({required this.action});

  final _InlineActionData action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => action.onTap(),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 14, color: AppColors.pine),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 11,
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

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: AppColors.mutedInk.withValues(alpha: 0.7)),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedInk,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _InsightLoadingState extends StatelessWidget {
  const _InsightLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.pine),
    );
  }
}

class _InsightErrorState extends StatelessWidget {
  const _InsightErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: AppColors.mutedInk,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load tractor insight right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again to fetch the FCA details and PMS history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedInk,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pine,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      height: 1,
      color: AppColors.ink.withValues(alpha: 0.08),
    );
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;
}

_StatusInfo _statusInfo(String status) {
  return switch (status) {
    'completed' => const _StatusInfo(
        background: Color(0xFFE8F5E9),
        foreground: AppColors.success,
        label: 'COMPLETED',
      ),
    'scheduled' => const _StatusInfo(
        background: Color(0xFFFFF3E0),
        foreground: AppColors.warning,
        label: 'PENDING',
      ),
    'in_progress' => const _StatusInfo(
        background: Color(0xFFE3F2FD),
        foreground: Color(0xFF1565C0),
        label: 'IN PROGRESS',
      ),
    'cancelled' => const _StatusInfo(
        background: Color(0xFFFFEBEE),
        foreground: AppColors.danger,
        label: 'CANCELLED',
      ),
    _ => _StatusInfo(
        background: const Color(0xFFF2F2F2),
        foreground: AppColors.mutedInk,
        label: status.toUpperCase(),
      ),
  };
}

Color _pmsStatusColor(String status) {
  return switch (status) {
    'due' => AppColors.danger,
    'upcoming' => AppColors.warning,
    'ok' => AppColors.success,
    _ => AppColors.mutedInk,
  };
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

String _formatDistance(double value) {
  return '${value.toStringAsFixed(1)} km';
}

String _formatHours(double value) {
  return '${value.toStringAsFixed(1)} h';
}

String _formatLastPms(PmsRecord? record) {
  if (record == null) {
    return 'No completed PMS';
  }

  return _formatDate(record.maintenanceDate ?? record.createdAt);
}

String _formatDate(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) {
    return 'Unavailable';
  }

  final parsed = DateTime.tryParse(rawDate);
  if (parsed == null) {
    return rawDate;
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

  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

Future<void> _launchExternalUri(
  BuildContext context,
  Uri uri, {
  required String failureMessage,
}) async {
  final launched = await launchUrl(uri);
  if (!context.mounted) {
    return;
  }

  if (!launched) {
    _showInsightFeedback(
      context,
      failureMessage,
      backgroundColor: AppColors.danger,
    );
  }
}

Future<void> _copyValue(
  BuildContext context, {
  required String value,
  required String label,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }

  _showInsightFeedback(
    context,
    label,
    backgroundColor: AppColors.success,
  );
}

void _showInsightFeedback(
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