import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/chat/widgets/ticket_conversation_sheet.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_network_photo_preview.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/chat_unread_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/realtime_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/services/websocket/pusher_client.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    this.backLocation = '/account/tickets',
    this.openChatOnLoad = false,
  });

  final int ticketId;
  final String backLocation;
  final bool openChatOnLoad;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  StreamSubscription<PusherEvent>? _eventSub;
  String _channelName = '';

  // Typing indicator state
  final _typingUserName = ValueNotifier<String?>(null);
  final _typingUserRole = ValueNotifier<String?>(null);
  Timer? _typingClearTimer;

  // Unread chat badge
  int _unreadCount = 0;
  bool _chatOpen = false;
  bool _didAutoOpenChat = false;

  @override
  void initState() {
    super.initState();
    _channelName = 'private-ticket.${widget.ticketId}';
    debugPrint(
      'TicketDetailScreen: subscribing to realtime room $_channelName',
    );

    context.read<TicketProvider>().fetchTicketDetail(widget.ticketId);

    // Subscribe to the ticket channel via WebSocket
    final realtime = context.read<RealtimeProvider>();
    realtime.subscribeToChannel(_channelName);

    // Listen for real-time events on this channel
    _eventSub = realtime.events?.listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(PusherEvent event) {
    if (event.channel != _channelName) return;

    if (event.event.contains('TicketCommentAdded')) {
      final commentData = event.data['comment'] as Map<String, dynamic>?;
      if (commentData != null && mounted) {
        debugPrint(
          'TicketDetailScreen: received comment event on $_channelName '
          'commentId=${commentData['id']} chatOpen=$_chatOpen',
        );
        context.read<TicketProvider>().appendRealtimeComment(commentData);
        // Increment unread count when chat is not open
        if (!_chatOpen) {
          setState(() => _unreadCount++);
        }
      }
    } else if (event.event == 'client-typing') {
      if (!mounted) return;
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final typingUserId = (event.data['user_id'] as num?)?.toInt();
      if (currentUserId != null && typingUserId == currentUserId) {
        return;
      }
      debugPrint(
        'TicketDetailScreen: received typing event on $_channelName '
        'from userId=$typingUserId name=${event.data['name']}',
      );
      _typingUserName.value = event.data['name'] as String?;
      _typingUserRole.value = event.data['role'] as String?;
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _typingUserName.value = null;
      });
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _typingClearTimer?.cancel();
    _typingUserName.dispose();
    _typingUserRole.dispose();
    context.read<ChatUnreadProvider>().setActiveTicketId(null);
    debugPrint(
      'TicketDetailScreen: unsubscribing from realtime room $_channelName',
    );
    // Unsubscribe from the ticket channel
    context.read<RealtimeProvider>().unsubscribeFromChannel(_channelName);
    super.dispose();
  }

  void _openChat() {
    final chatUnreadProvider = context.read<ChatUnreadProvider>();

    setState(() {
      _unreadCount = 0;
      _chatOpen = true;
    });

    chatUnreadProvider.setActiveTicketId(widget.ticketId);

    final provider = context.read<TicketProvider>();
    final ticket = provider.selectedTicket;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatSheet(
        ticketId: widget.ticketId,
        channelName: _channelName,
        comments: ticket?.comments ?? [],
        typingUserName: _typingUserName,
        typingUserRole: _typingUserRole,
      ),
    ).whenComplete(() {
      chatUnreadProvider.setActiveTicketId(null);
      if (mounted) setState(() => _chatOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    final ticket = provider.selectedTicket;
    final commentCount = ticket?.comments?.length ?? 0;

    if (widget.openChatOnLoad &&
        !_didAutoOpenChat &&
        !provider.loadingDetail &&
        ticket != null) {
      _didAutoOpenChat = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openChat();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Ticket Details'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(widget.backLocation),
        ),
      ),
      floatingActionButton: ticket != null
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  onPressed: _openChat,
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.chat_rounded, size: 24),
                ),
                // Unread badge
                if (_unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Comment count label
                if (_unreadCount == 0 && commentCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forest.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          commentCount > 99 ? '99+' : '$commentCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      body: provider.loadingDetail
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : ticket == null
          ? const Center(child: Text('Ticket not found'))
          : RefreshIndicator(
              color: AppColors.forest,
              onRefresh: () => provider.fetchTicketDetail(widget.ticketId),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header card ───
                    _DetailCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ticket.subject,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              _PriorityBadge(priority: ticket.priority),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _StatusBadge(status: ticket.status),
                              if (ticket.category != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    ticket.category!.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mutedInk,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (ticket.description != null) ...[
                            Text(
                              ticket.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.ink,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Submitted by',
                            value: ticket.submittedByName ?? 'Unknown',
                          ),
                          if (ticket.tractorLabel != null)
                            _InfoRow(
                              icon: Icons.agriculture_rounded,
                              label: 'Tractor',
                              value:
                                  '${ticket.tractorLabel} – ${ticket.tractorBrand ?? ''} ${ticket.tractorModel ?? ''}'
                                      .trim(),
                            ),
                          if (ticket.assignees != null &&
                              ticket.assignees!.isNotEmpty)
                            _InfoRow(
                              icon: Icons.support_agent_rounded,
                              label: 'Assigned to',
                              value: ticket.assigneeNames,
                            ),
                          _InfoRow(
                            icon: Icons.access_time_rounded,
                            label: 'Created',
                            value: ticket.timeAgo,
                          ),

                        ],
                      ),
                    ),

                    // ─── Issue photo ───
                    if (ticket.photoUrl != null &&
                        ticket.photoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Photo of Issue'),
                      const SizedBox(height: 8),
                      TicketNetworkPhotoPreview(
                        imageUrl: ticket.photoUrl!,
                        title: 'Issue photo',
                      ),
                    ],

                    // ─── Resolution info ───
                    if (ticket.status == 'resolved' ||
                        ticket.status == 'closed') ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Resolution'),
                      const SizedBox(height: 8),
                      _DetailCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ticket.resolvedByName != null)
                              _InfoRow(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Resolved by',
                                value: ticket.resolvedByName!,
                              ),
                            if (ticket.resolvedAt != null)
                              _InfoRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Resolved at',
                                value:
                                    '${ticket.resolvedAt!.day}/${ticket.resolvedAt!.month}/${ticket.resolvedAt!.year}',
                              ),
                            if (ticket.resolutionNotes != null &&
                                ticket.resolutionNotes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                ticket.resolutionNotes!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.ink,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (ticket.resolutionPhotoUrl != null &&
                          ticket.resolutionPhotoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TicketNetworkPhotoPreview(
                          imageUrl: ticket.resolutionPhotoUrl!,
                          title: 'Resolution photo',
                        ),
                      ],
                    ],

                    // ─── Discussion hint ───
                    const SizedBox(height: 16),
                    _DetailCard(
                      child: InkWell(
                        onTap: _openChat,
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.forest.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.chat_rounded,
                                size: 20,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Discussion',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    commentCount == 0
                                        ? 'No messages yet'
                                        : '$commentCount message${commentCount == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.mutedInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.mutedInk,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom spacer for FAB
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Chat Bottom Sheet ──────────────────────────

class _ChatSheet extends StatelessWidget {
  const _ChatSheet({
    required this.ticketId,
    required this.channelName,
    required this.comments,
    required this.typingUserName,
    required this.typingUserRole,
  });

  final int ticketId;
  final String channelName;
  final List<TicketComment> comments;
  final ValueNotifier<String?> typingUserName;
  final ValueNotifier<String?> typingUserRole;

  @override
  Widget build(BuildContext context) {
    final ticket = context.watch<TicketProvider>().selectedTicket;
    final currentComments = ticket?.comments ?? comments;
    final currentUser = context.read<AuthProvider>().currentUser;

    return TicketConversationSheet(
      comments: currentComments,
      typingUserName: typingUserName,
      typingUserRole: typingUserRole,
      currentUserId: currentUser?.id,
      onSendComment: ({body, attachment}) {
        return context.read<TicketProvider>().addComment(
          ticketId: ticketId,
          body: body,
          attachment: attachment,
          socketId: context.read<RealtimeProvider>().socketId,
        );
      },
      onTyping: () {
        final roleName = formatTicketChatRole(
          currentUser?.roles.firstOrNull ?? '',
        );

        context
            .read<RealtimeProvider>()
            .triggerClientEvent(channelName, 'client-typing', {
              'name': currentUser?.name ?? 'Someone',
              'role': roleName,
              'user_id': currentUser?.id,
            });
      },
    );
  }
}

// ─── Shared widgets ─────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mutedInk),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'open' => (const Color(0xFFE8F5E9), AppColors.forest),
      'in_progress' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'resolved' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'closed' => (Colors.grey.shade100, AppColors.mutedInk),
      _ => (Colors.grey.shade100, AppColors.mutedInk),
    };

    final label = switch (status) {
      'open' => 'Open',
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (priority) {
      'critical' => (const Color(0xFFFFEBEE), AppColors.danger),
      'high' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'medium' => (const Color(0xFFFFFDE7), const Color(0xFFF9A825)),
      'low' => (const Color(0xFFE8F5E9), AppColors.forest),
      _ => (Colors.grey.shade100, AppColors.mutedInk),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.toUpperCase(),
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
