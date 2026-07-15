import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/maintenance_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/tutorial_overlay.dart';
import 'package:tanodmobile/models/domain/distribution.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/models/domain/tps_fca.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

enum _TpsDashboardAction { refreshOfflineData }

class TpsScreen extends StatefulWidget {
  const TpsScreen({super.key});

  @override
  State<TpsScreen> createState() => _TpsScreenState();
}

class _TpsScreenState extends State<TpsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showTutorial = false;
  final _titleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<TpsProvider>().loadAll();
    context.read<MaintenanceProvider>().fetchTractors(pageSize: 20);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  void _maybeShowTutorial() {
    if (!mounted) return;
    try {
      final hive = context.read<HiveService>();
      if (hive.getPreference('tutorial_tps') == 'true') return;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || _showTutorial) return;
        setState(() => _showTutorial = true);
      });
    } catch (_) {}
  }

  void _onTutorialComplete() {
    if (!mounted) return;
    context.read<HiveService>().savePreference('tutorial_tps', 'true');
    setState(() => _showTutorial = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleDashboardAction(
    _TpsDashboardAction action,
    AuthProvider authProvider,
  ) async {
    switch (action) {
      case _TpsDashboardAction.refreshOfflineData:
        await _openOfflineRefresh(authProvider);
    }
  }

  Future<void> _openOfflineRefresh(AuthProvider authProvider) async {
    if (!authProvider.isConnected) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Internet connection is required to refresh offline data.',
            ),
          ),
        );
      return;
    }

    await context.push('/tps/offline-download?manual=1');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TpsProvider, AuthProvider>(
      builder: (context, provider, authProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          floatingActionButton: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final index = _tabController.index;
              final fabLabel = switch (index) {
                1 => context.tr('distribute_tractor'),
                2 => 'Add FCA',
                _ => null,
              };
              final fabIcon = switch (index) {
                1 => Icons.add_rounded,
                2 => Icons.groups_rounded,
                _ => null,
              };
              final fabAction = switch (index) {
                1 => () => context.go('/tps/distribute'),
                2 => () => context.go('/tps/fcas/create'),
                _ => null,
              };
              final showFab = fabAction != null;

              return AnimatedScale(
                scale: showFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: showFab
                    ? FloatingActionButton.extended(
                        onPressed: fabAction,
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        icon: Icon(fabIcon, size: 20),
                        label: Text(fabLabel!),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    provider.loadAll(),
                    context.read<MaintenanceProvider>().fetchTractors(
                      pageSize: 20,
                    ),
                  ]);
                },
                color: AppColors.forest,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        floating: true,
                        snap: true,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        toolbarHeight: 70,
                        actions: [
                          PopupMenuButton<_TpsDashboardAction>(
                            tooltip: 'TPS actions',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: AppColors.ink,
                            ),
                            onSelected: (action) =>
                                _handleDashboardAction(action, authProvider),
                            itemBuilder: (context) => const [
                              PopupMenuItem<_TpsDashboardAction>(
                                value: _TpsDashboardAction.refreshOfflineData,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_sync_rounded,
                                      color: AppColors.forest,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text('Refresh offline data'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        title: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TSR Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manage assigned tractors & services',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedInk,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(132),
                          child: Column(
                            children: [
                              _SummaryRow(provider: provider),
                              const SizedBox(height: 8),
                              Container(
                                color: Colors.white,
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: AppColors.forest,
                                  unselectedLabelColor: AppColors.mutedInk,
                                  indicatorColor: AppColors.forest,
                                  indicatorSize: TabBarIndicatorSize.label,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  tabs: const [
                                    Tab(text: 'Repair & Maintenance'),
                                    Tab(text: 'Distributions'),
                                    Tab(text: 'FCAs'),
                                    Tab(text: 'Tractors'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _TicketsTab(provider: provider),
                      _DistributionsTab(provider: provider),
                      _FcasTab(provider: provider),
                      const _MaintenanceTab(),
                    ],
                  ),
                ),
              ),
              if (_showTutorial)
                TutorialOverlayWidget(
                  steps: [
                    TutorialStep(
                      targetKey: _titleKey,
                      title: 'TSR Dashboard',
                      description:
                          'Your TPS control center. Switch between Repair & '
                          'Maintenance, Distributions, FCAs, and Tractors tabs '
                          'using the tabs above.',
                      tooltipPosition: TutorialTooltipPosition.bottom,
                    ),
                  ],
                  onComplete: _onTutorialComplete,
                  onSkip: _onTutorialComplete,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.provider});

  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.ticketsLoading &&
        provider.distributionsLoading &&
        provider.tickets.isEmpty &&
        provider.distributions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.forest,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatChip(
            label: 'Tractors',
            value: provider.tractorsCount.toString(),
            icon: Icons.agriculture_rounded,
            color: AppColors.forest,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Open R&M',
            value: provider.openTickets.toString(),
            icon: Icons.confirmation_number_rounded,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'PMS Due',
            value: provider.pendingMaintenance.toString(),
            icon: Icons.build_circle_rounded,
            color: AppColors.clay,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Distributions',
            value: provider.activeDistributions.toString(),
            icon: Icons.local_shipping_rounded,
            color: AppColors.pine,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Repair & Maintenance Tab ──────────────────

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: provider.ticketStatusFilter == null,
                onTap: () => provider.setTicketStatusFilter(null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Open',
                selected: provider.ticketStatusFilter == 'open',
                onTap: () => provider.setTicketStatusFilter('open'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Resolved',
                selected: provider.ticketStatusFilter == 'resolved',
                onTap: () => provider.setTicketStatusFilter('resolved'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _PagedSearchList<Ticket>(
            key: ValueKey(
              'tickets_${provider.tickets.length}_${provider.ticketsLoading}',
            ),
            items: provider.tickets,
            loading: provider.ticketsLoading,
            hasMore: provider.hasMoreTickets,
            searchQuery: provider.ticketSearchQuery,
            searchHint: 'Search ticket, tractor, or assignee',
            emptyIcon: Icons.confirmation_number_outlined,
            emptyMessage: 'No tickets',
            onRefresh: () =>
                provider.fetchTickets(status: provider.ticketStatusFilter),
            onLoadMore: provider.fetchMoreTickets,
            onSearchChanged: (query) => provider.setTicketSearchQuery(
              query,
              status: provider.ticketStatusFilter,
            ),
            itemBuilder: (context, ticket) => GestureDetector(
              onTap: () => context.go('/tps/tickets/${ticket.id}'),
              child: _TicketCard(ticket: ticket),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final Ticket ticket;

  Color get _statusColor {
    switch (ticket.status) {
      case 'open':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.pine;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.mutedInk;
      default:
        return AppColors.mutedInk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  size: 20,
                  color: _statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ticket.tractorLabel != null)
                      Text(
                        ticket.tractorLabel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedInk,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (ticket.description != null) ...[
            const SizedBox(height: 10),
            Text(
              ticket.description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedInk,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (ticket.isPartial)
                _Badge(
                  label: 'Partially Resolved',
                  color: const Color(0xFFE65100),
                )
              else
                _Badge(label: ticket.statusLabel, color: _statusColor),
              const Spacer(),
              Text(
                ticket.timeAgo,
                style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── FCAs Tab ───────────────────────────────────

class _FcasTab extends StatelessWidget {
  const _FcasTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    return _PagedSearchList<TpsFca>(
      key: ValueKey('fcas_${provider.fcas.length}_${provider.fcasLoading}'),
      items: provider.fcas,
      loading: provider.fcasLoading,
      hasMore: provider.hasMoreFcas,
      searchQuery: provider.fcaSearchQuery,
      searchHint: 'Search FCA, cooperative, phone, or email',
      emptyIcon: Icons.groups_2_outlined,
      emptyMessage: 'No FCAs',
      onRefresh: () => provider.fetchFcas(),
      onLoadMore: provider.fetchMoreFcas,
      onSearchChanged: (query) => provider.setFcaSearchQuery(query),
      itemBuilder: (_, fca) => _FcaCard(fca: fca),
    );
  }
}

class _FcaCard extends StatelessWidget {
  const _FcaCard({required this.fca});
  final TpsFca fca;

  String _formatCardDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$month-$day-${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final receivedLabel = fca.dateReceived == null
        ? null
        : _formatCardDate(fca.dateReceived!);
    final parkingLabel = fca.locationLabel.isNotEmpty
        ? fca.locationLabel
        : (fca.parkingLatitude != null && fca.parkingLongitude != null)
        ? '${fca.parkingLatitude!.toStringAsFixed(4)}, ${fca.parkingLongitude!.toStringAsFixed(4)}'
        : null;
    final createdLabel = fca.createdAt == null
        ? null
        : _formatCardDate(fca.createdAt!);
    final statusColor = fca.isCompletedData
        ? AppColors.success
        : AppColors.warning;
    final statusIcon = fca.isCompletedData
        ? Icons.verified_rounded
        : Icons.edit_note_rounded;
    final title = fca.organizationName?.trim().isNotEmpty == true
        ? fca.organizationName!.trim()
        : fca.fullName;
    final subtitle = fca.organizationName?.trim().isNotEmpty == true
        ? fca.fullName
        : 'Organization name pending';
    final completionPercent = (fca.dataCompletionRatio * 100).round();
    final completionLabel = fca.isCompletedData
        ? 'Main details are complete.'
        : 'Some details are still missing.';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, statusColor.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withValues(alpha: 0.45)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.groups_2_rounded,
                          size: 20,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _FcaStatusPill(
                                  label: fca.dataStatusLabel,
                                  color: statusColor,
                                  icon: statusIcon,
                                ),
                                if (createdLabel != null)
                                  _FcaHeaderDatePill(label: createdLabel),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedInk,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Edit FCA',
                        child: Material(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => context.go('/tps/fcas/${fca.id}/edit'),
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.query_stats_rounded,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                completionLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$completionPercent%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: fca.dataCompletionRatio,
                                  minHeight: 6,
                                  backgroundColor: statusColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${fca.completedDataCheckpoints}/${TpsFca.totalDataCheckpoints}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FcaMetaPill(
                        icon: Icons.call_outlined,
                        text: fca.contactLabel.isNotEmpty
                            ? fca.contactLabel
                            : 'Contact pending',
                        color: fca.hasContactDetails
                            ? AppColors.forest
                            : AppColors.warning,
                      ),
                      _FcaMetaPill(
                        icon: Icons.place_outlined,
                        text: parkingLabel ?? 'Location pending',
                        color: fca.hasLocationDetails
                            ? AppColors.pine
                            : AppColors.warning,
                      ),
                      _FcaMetaPill(
                        icon: Icons.calendar_month_outlined,
                        text: receivedLabel ?? 'Date pending',
                        color: fca.hasReceivedDetails
                            ? AppColors.clay
                            : AppColors.warning,
                      ),
                      if (fca.province?.isNotEmpty == true)
                        _FcaMetaPill(
                          icon: Icons.map_outlined,
                          text: fca.province!,
                          color: AppColors.forest,
                        ),
                    ],
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

// ─── Maintenance Tab ────────────────────────────

class _MaintenanceTab extends StatelessWidget {
  const _MaintenanceTab();

  void _showPmsActions(BuildContext ctx, MaintenanceTractor tractor) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedInk.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                tractor.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.history_rounded,
                color: AppColors.forest,
              ),
              title: const Text('PMS History'),
              subtitle: const Text('View past PMS records'),
              onTap: () {
                Navigator.pop(sheetCtx);
                ctx.push('/account/maintenance/history', extra: tractor);
              },
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceProvider>();
    final tractors = List<MaintenanceTractor>.from(provider.tractors)
      ..sort((a, b) {
        const order = {'due': 0, 'upcoming': 1, 'ok': 2};
        final cmp = (order[a.pmsStatus] ?? 2).compareTo(
          order[b.pmsStatus] ?? 2,
        );
        if (cmp != 0) return cmp;
        return a.totalRunningHours.compareTo(b.totalRunningHours);
      });

    return _PagedSearchList<MaintenanceTractor>(
      key: ValueKey('maint_${tractors.length}_${provider.loading}'),
      items: tractors,
      loading: provider.loading,
      hasMore: provider.hasMore,
      searchQuery: provider.searchQuery,
      searchHint: 'Search tractor, brand, assignee, or IMEI',
      emptyIcon: Icons.build_circle_outlined,
      emptyMessage: 'No maintenance data',
      onRefresh: () => provider.fetchTractors(pageSize: 20),
      onLoadMore: () => provider.fetchMore(pageSize: 20),
      onSearchChanged: (query) => provider.setSearchQuery(query, pageSize: 20),
      itemBuilder: (context, tractor) => GestureDetector(
        onTap: () => _showPmsActions(context, tractor),
        child: _MaintenanceCard(tractor: tractor),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.tractor});
  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: tractor.isPmsDue
            ? Border.all(
                color: AppColors.danger.withValues(alpha: 0.4),
                width: 1.5,
              )
            : tractor.isPmsUpcoming
            ? Border.all(
                color: const Color(0xFFE65100).withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Column(
        children: [
          // ─── Header row ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Tractor icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: tractor.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            tractor.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.agriculture_rounded,
                              color: AppColors.forest,
                              size: 24,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.agriculture_rounded,
                          color: AppColors.forest,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                // Tractor info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tractor.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tractor.brandModel.isNotEmpty)
                        Text(
                          tractor.brandModel,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                          ),
                        ),
                    ],
                  ),
                ),
                // PMS badge
                _PmsBadge(status: tractor.pmsStatus),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Stats row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Running Hours',
                  value: '${tractor.totalRunningHours.toStringAsFixed(1)}h',
                ),
                const SizedBox(width: 12),
                _StatTile(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: '${tractor.totalDistance.toStringAsFixed(1)} km',
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ─── PMS progress ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PmsProgress(tractor: tractor),
          ),

          // ─── Assignee ───
          if (tractor.assigneeName != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: AppColors.mutedInk.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tractor.assigneeName!,
                    style: TextStyle(fontSize: 12, color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ─── Distributions Tab ──────────────────────────

class _DistributionsTab extends StatelessWidget {
  const _DistributionsTab({required this.provider});
  final TpsProvider provider;

  @override
  Widget build(BuildContext context) {
    return _PagedSearchList<Distribution>(
      key: ValueKey(
        'dist_${provider.distributions.length}_${provider.distributionsLoading}',
      ),
      items: provider.distributions,
      loading: provider.distributionsLoading,
      hasMore: provider.hasMoreDistributions,
      searchQuery: provider.distributionSearchQuery,
      searchHint: 'Search tractor, FCA, email, or area',
      emptyIcon: Icons.local_shipping_outlined,
      emptyMessage: 'No distributions',
      onRefresh: () => provider.fetchDistributions(),
      onLoadMore: provider.fetchMoreDistributions,
      onSearchChanged: (query) => provider.setDistributionSearchQuery(query),
      listPadding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemBuilder: (_, distribution) =>
          _DistributionCard(distribution: distribution),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.distribution});
  final Distribution distribution;

  Color get _statusColor {
    switch (distribution.status) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.pine;
      case 'recalled':
        return AppColors.danger;
      default:
        return AppColors.mutedInk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pine.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 20,
                  color: AppColors.pine,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distribution.tractorLabel ?? 'Tractor',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (distribution.distributedToName != null)
                      Text(
                        'To: ${distribution.distributedToName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedInk,
                        ),
                      ),
                  ],
                ),
              ),
              _Badge(label: distribution.statusLabel, color: _statusColor),
            ],
          ),
          if (distribution.area != null) ...[
            const SizedBox(height: 10),
            _InfoChip(icon: Icons.place_rounded, text: distribution.area!),
          ],
        ],
      ),
    );
  }
}

// ─── Shared widgets ─────────────────────────────

class _PagedSearchList<T> extends StatefulWidget {
  const _PagedSearchList({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.searchQuery,
    required this.searchHint,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onSearchChanged,
    required this.itemBuilder,
    this.listPadding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  final List<T> items;
  final bool loading;
  final bool hasMore;
  final String searchQuery;
  final String searchHint;
  final IconData emptyIcon;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(String query) onSearchChanged;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsets listPadding;

  @override
  State<_PagedSearchList<T>> createState() => _PagedSearchListState<T>();
}

class _PagedSearchListState<T> extends State<_PagedSearchList<T>> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _PagedSearchList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != _searchController.text) {
      _searchController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 180) {
      return;
    }

    widget.onLoadMore();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      widget.onSearchChanged(value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _DashboardSearchField(
            controller: _searchController,
            hintText: widget.searchHint,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
          ),
        ),
        Expanded(
          child: widget.loading && widget.items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.forest),
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  color: AppColors.forest,
                  child: widget.items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
                          children: [
                            _buildEmpty(
                              widget.emptyIcon,
                              query.isEmpty
                                  ? widget.emptyMessage
                                  : 'No results found',
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: widget.listPadding,
                          itemCount:
                              widget.items.length + (widget.hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= widget.items.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: widget.loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.forest,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }

                            return widget.itemBuilder(
                              context,
                              widget.items[index],
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _DashboardSearchField extends StatelessWidget {
  const _DashboardSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedInk),
        suffixIcon: hasValue
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.mutedInk,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

Widget _buildEmpty(IconData icon, String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: AppColors.mutedInk.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedInk,
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.mutedInk,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FcaStatusPill extends StatelessWidget {
  const _FcaStatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FcaHeaderDatePill extends StatelessWidget {
  const _FcaHeaderDatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mutedInk.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: AppColors.mutedInk,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _FcaMetaPill extends StatelessWidget {
  const _FcaMetaPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedInk),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Tractor card helpers ───────────────────────

class _PmsBadge extends StatelessWidget {
  const _PmsBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String text) = switch (status) {
      'due' => (const Color(0xFFFFEBEE), AppColors.danger, 'PMS DUE'),
      'upcoming' => (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        'UPCOMING',
      ),
      _ => (const Color(0xFFE8F5E9), AppColors.forest, 'OK'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.mutedInk),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: AppColors.mutedInk),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
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

class _PmsProgress extends StatelessWidget {
  const _PmsProgress({required this.tractor});

  final MaintenanceTractor tractor;

  @override
  Widget build(BuildContext context) {
    final nextPms = tractor.nextPmsHours;
    if (nextPms == null) return const SizedBox.shrink();

    const milestones = [0, 50, 100, 200, 300];
    double prevMilestone = 0;
    for (final m in milestones) {
      if (m < nextPms) {
        prevMilestone = m.toDouble();
      }
    }
    if (nextPms > 300) {
      prevMilestone = nextPms - 300;
    }

    final range = nextPms - prevMilestone;
    final progress = range > 0
        ? ((tractor.totalRunningHours - prevMilestone) / range).clamp(0.0, 1.0)
        : 0.0;

    final progressColor = tractor.isPmsDue
        ? AppColors.danger
        : tractor.isPmsUpcoming
        ? const Color(0xFFE65100)
        : AppColors.forest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Next PMS at ${nextPms.toStringAsFixed(0)}h',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: progressColor,
              ),
            ),
            Text(
              tractor.hoursUntilNextPms.isFinite
                  ? '${tractor.hoursUntilNextPms.toStringAsFixed(1)}h remaining'
                  : '',
              style: TextStyle(fontSize: 11, color: AppColors.mutedInk),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: progressColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}
