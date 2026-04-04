import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/feedback_provider.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FeedbackProvider>().fetchFeedbacks();
  }

  Future<void> _onRefresh() async {
    await context.read<FeedbackProvider>().fetchFeedbacks();
  }

  bool get _isFarmer {
    final user = context.read<AuthProvider>().currentUser;
    return user?.roles.contains('farmer') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedbackProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account'),
        ),
      ),
      floatingActionButton: _isFarmer
          ? FloatingActionButton(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              onPressed: () => context.go('/account/feedback/create'),
              child: const Icon(Icons.add_rounded),
            )
          : null,
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
              : provider.feedbacks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 56,
                              color:
                                  AppColors.mutedInk.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'No feedback yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk,
                            ),
                          ),
                          if (_isFarmer) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Tap + to share your experience',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.mutedInk),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: provider.feedbacks.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _FeedbackCard(
                              feedback: provider.feedbacks[index]);
                        },
                      ),
                    ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final FarmerFeedbackItem feedback;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Header with tractor info and status
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.agriculture_rounded,
                      color: AppColors.forest, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tractorLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (feedback.submitterName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          feedback.submitterName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status: feedback.status ?? 'pending'),
              ],
            ),
          ),

          // Rating stars
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                ...List.generate(5, (i) {
                  return Icon(
                    i < (feedback.rating ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 22,
                    color: i < (feedback.rating ?? 0)
                        ? AppColors.gold
                        : AppColors.mutedInk.withValues(alpha: 0.2),
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${feedback.rating ?? 0}/5',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),

          // Feedback text
          if (feedback.feedback != null &&
              feedback.feedback!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                feedback.feedback!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Category + time
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                if (feedback.category != null &&
                    feedback.category!.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.pine.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      feedback.category!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.pine,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Icon(Icons.access_time_rounded,
                    size: 13,
                    color: AppColors.mutedInk.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  feedback.timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedInk.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Admin response (if reviewed)
          if (feedback.adminResponse != null &&
              feedback.adminResponse!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.forest.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 14, color: AppColors.forest),
                      SizedBox(width: 6),
                      Text(
                        'Admin Response',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    feedback.adminResponse!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _tractorLabel {
    final parts = <String>[];
    if (feedback.tractorLabel != null) parts.add(feedback.tractorLabel!);
    if (feedback.tractorBrand != null) parts.add(feedback.tractorBrand!);
    if (feedback.tractorModel != null) parts.add(feedback.tractorModel!);
    return parts.isNotEmpty ? parts.join(' · ') : 'Tractor';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'reviewed' => (
        AppColors.forest.withValues(alpha: 0.1),
        AppColors.forest,
      ),
      'resolved' => (
        AppColors.success.withValues(alpha: 0.1),
        AppColors.success,
      ),
      _ => (
        AppColors.gold.withValues(alpha: 0.12),
        AppColors.gold,
      ),
    };

    final label = switch (status) {
      'reviewed' => 'Reviewed',
      'resolved' => 'Resolved',
      _ => 'Pending',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
