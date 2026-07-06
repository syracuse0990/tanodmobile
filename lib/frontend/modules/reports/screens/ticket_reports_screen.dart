import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/report_provider.dart';
import 'package:tanodmobile/models/domain/ticket_report.dart';

class TicketReportsScreen extends StatefulWidget {
  const TicketReportsScreen({super.key});

  @override
  State<TicketReportsScreen> createState() => _TicketReportsScreenState();
}

class _TicketReportsScreenState extends State<TicketReportsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportProvider>().fetchTicketReports(refresh: true);
  }

  Future<void> _onRefresh() async {
    await context.read<ReportProvider>().fetchTicketReports(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Ticket Reports'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account'),
        ),
      ),
      body: provider.ticketReportsLoading && provider.ticketReports.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest))
          : provider.ticketReportsError != null &&
                  provider.ticketReports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48,
                          color:
                              AppColors.mutedInk.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(provider.ticketReportsError!,
                          style:
                              const TextStyle(color: AppColors.mutedInk)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _onRefresh,
                        child: const Text('Retry',
                            style: TextStyle(color: AppColors.forest)),
                      ),
                    ],
                  ),
                )
              : provider.ticketReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 56,
                              color: AppColors.mutedInk
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'No ticket reports yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Reports are automatically generated when\nyou resolve a ticket.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: provider.ticketReports.length +
                            (provider.hasMoreTicketReports ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == provider.ticketReports.length) {
                            context
                                .read<ReportProvider>()
                                .fetchMoreTicketReports();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                            );
                          }

                          final report = provider.ticketReports[index];
                          return _TicketReportCard(
                            report: report,
                            onTap: () => context.go(
                              '/account/ticket-reports/${report.id}',
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _TicketReportCard extends StatelessWidget {
  const _TicketReportCard({
    required this.report,
    required this.onTap,
  });

  final TicketReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: report.isFinalized
                    ? AppColors.forest.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: report.isFinalized
                            ? AppColors.forest.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        size: 18,
                        color: report.isFinalized
                            ? AppColors.forest
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.subject,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (report.tractorDisplay.isNotEmpty)
                            Text(
                              report.tractorDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status and info row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: report.isFinalized
                            ? AppColors.forest.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.isFinalized ? 'Finalized' : 'Draft',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: report.isFinalized
                              ? AppColors.forest
                              : Colors.orange,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.mutedInk.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      report.generatedAtFormatted,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedInk.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.mutedInk),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
