import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/chat_unread_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/tutorial_overlay.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showTutorial = false;
  final _titleKey = GlobalKey();

  bool get _isTps =>
      context.read<AuthProvider>().session?.roles.contains('tps') ?? false;

  bool get _isFca =>
      context.read<AuthProvider>().session?.roles.contains('fca') ?? false;

  int? get _currentUserId => context.read<AuthProvider>().currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _fetchInitial();
    });
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  void _maybeShowTutorial() {
    if (!mounted) return;
    try {
      final hive = context.read<HiveService>();
      if (!hive.tutorialsEnabled) return;
      if (hive.getPreference('tutorial_chat') == 'true') return;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || _showTutorial) return;
        setState(() => _showTutorial = true);
      });
    } catch (_) {}
  }

  void _onTutorialComplete() {
    if (!mounted) return;
    context.read<HiveService>().savePreference('tutorial_chat', 'true');
    setState(() => _showTutorial = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _fetchInitial() {
    final unreadRefresh = context
        .read<ChatUnreadProvider>()
        .refreshUnreadCounts();

    if (_isTps) {
      return Future.wait([
        context.read<TpsProvider>().fetchChatTickets(),
        unreadRefresh,
      ]);
    }

    return Future.wait([
      context.read<TicketProvider>().fetchChatTickets(),
      unreadRefresh,
    ]);
  }

  Future<void> _fetchMore() {
    if (_isTps) {
      return context.read<TpsProvider>().fetchMoreChatTickets();
    }

    return context.read<TicketProvider>().fetchMoreChatTickets();
  }

  bool _matchesSearch(Ticket ticket) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final haystack = [
      ticket.subject,
      ticket.chatPreview,
      ticket.tractorLabel,
      ticket.tractorBrand,
      ticket.tractorModel,
      ticket.submittedByName,
      ticket.statusLabel,
      ticket.priorityLabel,
    ].whereType<String>().join(' ').toLowerCase();

    return haystack.contains(query);
  }

  void _handleScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 180) {
      return;
    }

    _fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    final tpsProvider = context.watch<TpsProvider>();
    final ticketProvider = context.watch<TicketProvider>();
    final chatUnreadProvider = context.watch<ChatUnreadProvider>();

    final tickets = _isTps
        ? tpsProvider.chatTickets
        : ticketProvider.chatTickets;
    final visibleTickets = tickets.where(_matchesSearch).toList();
    final loading = _isTps
        ? tpsProvider.chatTicketsLoading
        : ticketProvider.chatLoading;
    final error = _isTps
        ? tpsProvider.chatTicketsError
        : ticketProvider.chatError;
    final hasMore = _isTps
        ? tpsProvider.hasMoreChatTickets
        : ticketProvider.hasMoreChatTickets;
    final totalUnread = chatUnreadProvider.totalUnreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  _ChatHeroHeader(
                    key: _titleKey,
                    title: context.tr('nav_chat'),
                    subtitle: _isTps
                        ? 'All ticket conversations across the tractor fleet.'
                        : 'Chats from tickets you created for support.',
                    totalRooms: tickets.length,
                    unreadCount: totalUnread,
                  ),
                  const SizedBox(height: 14),
                  _ChatSearchField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                  const SizedBox(height: 12),
                  _ChatScopeBar(
                    isTps: _isTps,
                    totalRooms: tickets.length,
                    visibleRooms: visibleTickets.length,
                    searchActive: _searchQuery.trim().isNotEmpty,
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading && tickets.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.forest),
                    )
                  : error != null && tickets.isEmpty
                  ? _ChatRoomsErrorState(onRetry: _fetchInitial)
                  : tickets.isEmpty
                  ? _EmptyChatRoomsState(showCreateHint: _isFca)
                  : visibleTickets.isEmpty
                  ? _EmptySearchState(query: _searchQuery)
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: _fetchInitial,
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        itemCount:
                            visibleTickets.length +
                            (hasMore && _searchQuery.trim().isEmpty ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index >= visibleTickets.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(
                                  color: AppColors.forest,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          final ticket = visibleTickets[index];

                          return _ChatRoomCard(
                            ticket: ticket,
                            unreadCount: chatUnreadProvider
                                .unreadCountForTicket(ticket.id),
                            currentUserId: _currentUserId,
                            isTps: _isTps,
                            onTap: () => context.go('/chat/${ticket.id}'),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
            if (_showTutorial)
              TutorialOverlayWidget(
                steps: [
                  TutorialStep(
                    targetKey: _titleKey,
                    title: 'Chat & Tickets',
                    description:
                        'View all your ticket conversations here. Each ticket '
                        'shows the subject, status, and priority. Tap a ticket '
                        'to open the conversation.',
                    tooltipPosition: TutorialTooltipPosition.bottom,
                  ),
                ],
                onComplete: _onTutorialComplete,
                onSkip: _onTutorialComplete,
              ),
        ],
      ),
    );
  }
}

class _ChatHeroHeader extends StatelessWidget {
  const _ChatHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.totalRooms,
    required this.unreadCount,
  });

  final String title;
  final String subtitle;
  final int totalRooms;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF214A3F), Color(0xFF3E7460)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A17352D),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroMetricPill(
                      label: totalRooms == 1 ? '1 room' : '$totalRooms rooms',
                    ),
                    _HeroMetricPill(
                      label: unreadCount == 1
                          ? '1 unread'
                          : '$unreadCount unread',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricPill extends StatelessWidget {
  const _HeroMetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D102A24),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search tickets, tractors, or names',
          hintStyle: TextStyle(
            color: AppColors.mutedInk.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.ink),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.mutedInk,
                  ),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _ChatScopeBar extends StatelessWidget {
  const _ChatScopeBar({
    required this.isTps,
    required this.totalRooms,
    required this.visibleRooms,
    required this.searchActive,
  });

  final bool isTps;
  final int totalRooms;
  final int visibleRooms;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            searchActive
                ? '$visibleRooms of $totalRooms conversations'
                : (isTps
                      ? 'Showing all ticket chats across the fleet'
                      : 'Showing only chats from tickets you created'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0EC),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isTps ? 'Fleet-wide' : 'Created by you',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatRoomCard extends StatelessWidget {
  const _ChatRoomCard({
    required this.ticket,
    required this.unreadCount,
    required this.currentUserId,
    required this.isTps,
    required this.onTap,
  });

  final Ticket ticket;
  final int unreadCount;
  final int? currentUserId;
  final bool isTps;
  final VoidCallback onTap;

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '';
    }

    final now = DateTime.now();
    final localValue = value.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(
      localValue.year,
      localValue.month,
      localValue.day,
    );
    final dayDiff = today.difference(messageDay).inDays;

    String formatHour(DateTime dateTime) {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }

    if (dayDiff == 0) {
      return formatHour(localValue);
    }

    if (dayDiff == 1) {
      return 'Yesterday';
    }

    if (dayDiff < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[localValue.weekday - 1];
    }

    return '${localValue.month}/${localValue.day}';
  }

  Color get _priorityColor {
    switch (ticket.priority.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFE46B64);
      case 'medium':
        return const Color(0xFFF0B44F);
      case 'low':
        return const Color(0xFF55B68C);
      default:
        return AppColors.gold;
    }
  }

  String get _titleSeed {
    return ticket.tractorLabel?.trim().isNotEmpty == true
        ? ticket.tractorLabel!.trim()
        : (ticket.submittedByName?.trim().isNotEmpty == true
              ? ticket.submittedByName!.trim()
              : ticket.subject.trim());
  }

  String get _initials {
    final words = _titleSeed
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) {
      return '#${ticket.id}';
    }

    return words.map((word) => word.characters.first.toUpperCase()).join();
  }

  String get _previewText {
    final preview = ticket.chatPreview;
    final lastCommentUserId = ticket.lastComment?.userId;

    if (lastCommentUserId != null && lastCommentUserId == currentUserId) {
      return 'You: $preview';
    }

    return preview;
  }

  String get _metaLine {
    final parts = <String>[];
    final tractorLabel = ticket.tractorLabel?.trim();
    final submittedByName = ticket.submittedByName?.trim();
    final assigneeNames = ticket.assigneeNames.trim();

    if (tractorLabel != null && tractorLabel.isNotEmpty) {
      parts.add(tractorLabel);
    }

    if (isTps && submittedByName != null && submittedByName.isNotEmpty) {
      parts.add(submittedByName);
    }

    if (!isTps && assigneeNames.isNotEmpty && assigneeNames != 'Unassigned') {
      parts.add(assigneeNames);
    }

    return parts.isEmpty ? 'Ticket #${ticket.id}' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatTime(ticket.activityAt);
    final previewText = _previewText;
    final metaLine = _metaLine;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: unreadCount > 0 ? Colors.white : const Color(0xFFFDFDFC),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: unreadCount > 0
                  ? const Color(0xFFD8E4DE)
                  : const Color(0xFFE9EEEA),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10152E28),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _priorityColor.withValues(alpha: 0.95),
                          AppColors.forest,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: unreadCount > 0
                            ? const Color(0xFF4F7BFF)
                            : const Color(0xFFCCD5D0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: unreadCount > 0
                                ? AppColors.forest
                                : AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      previewText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: unreadCount > 0
                            ? AppColors.ink
                            : AppColors.mutedInk,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metaLine,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusPill(status: ticket.statusLabel),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          _UnreadBubble(count: unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  IconData get _icon {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle_outline_rounded;
      case 'closed':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: AppColors.mutedInk),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBubble extends StatelessWidget {
  const _UnreadBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      constraints: const BoxConstraints(minWidth: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF4F7BFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EmptyChatRoomsState extends StatelessWidget {
  const _EmptyChatRoomsState({required this.showCreateHint});

  final bool showCreateHint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.forest,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No chat rooms yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showCreateHint
                  ? 'Create a ticket and it will appear here as a shared discussion room for your support team.'
                  : 'Ticket discussions from across the fleet will appear here once tickets are created.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRoomsErrorState extends StatelessWidget {
  const _ChatRoomsErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

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
              'Unable to load chat rooms right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try again to load the ticket conversations available to your role.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.mutedInk,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching conversations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No ticket rooms matched "$query". Try another ticket subject, tractor, or sender name.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
