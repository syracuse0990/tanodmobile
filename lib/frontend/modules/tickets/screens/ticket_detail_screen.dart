import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:tanodmobile/frontend/modules/chat/widgets/ticket_conversation_sheet.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_network_photo_preview.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/chat_unread_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/realtime_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/models/domain/tractor_part.dart';
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

  void _showResolveSheet() {
    final ticket = context.read<TicketProvider>().selectedTicket;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ResolveSheet(
        ticketId: widget.ticketId,
        onResolved: () {
          context.read<TicketProvider>().fetchTicketDetail(widget.ticketId);
        },
        ticket: ticket,
      ),
    );
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
    final authProvider = context.watch<AuthProvider>();
    final isTps = authProvider.currentUser?.roles.contains('tps') ?? false;

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
        title: const Text('Repair & Maintenance Details'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(widget.backLocation),
        ),
      ),
      floatingActionButton: ticket != null &&
              ticket.status != 'resolved' &&
              ticket.status != 'closed'
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
                          // Ticket ID + date row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.forest.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TAN-${ticket.id.toString().padLeft(4, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_rounded, size: 12, color: AppColors.mutedInk.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                ticket.timeAgo,
                                style: TextStyle(fontSize: 11, color: AppColors.mutedInk.withValues(alpha: 0.7)),
                              ),
                              const Spacer(),
                              _StatusBadge(status: ticket.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ticket.subject,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (ticket.category != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.forest.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ticket.category!.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          // ─── Resolution Type ───
                          if (ticket.actionTaken != null &&
                              ticket.actionTaken!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: ticket.status == 'resolved'
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ticket.status == 'resolved'
                                        ? Icons.check_circle_rounded
                                        : Icons.pending_rounded,
                                    size: 16,
                                    color: ticket.status == 'resolved'
                                        ? AppColors.forest
                                        : const Color(0xFFE65100),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    ticket.actionTaken!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ticket.status == 'resolved'
                                          ? AppColors.forest
                                          : const Color(0xFFE65100),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ─── PMS Checklist ───
                          if (ticket.category == 'PMS' &&
                              ticket.pmsChecklist != null &&
                              ticket.pmsChecklist!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PMS Checklist',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...ticket.pmsChecklist!.map((item) {
                                    final done = item['done'] == true ||
                                        item['done'] == '1' ||
                                        item['done'] == 1;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        children: [
                                          Icon(
                                            done
                                                ? Icons.check_circle_rounded
                                                : Icons.radio_button_unchecked_rounded,
                                            size: 18,
                                            color: done
                                                ? AppColors.forest
                                                : AppColors.mutedInk
                                                    .withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item['name']?.toString() ?? '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: done
                                                    ? AppColors.forest
                                                    : AppColors.ink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
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
                          if (isTps && ticket.isResolvable) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _showResolveSheet,
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20,
                                ),
                                label: const Text('Resolve Ticket'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ─── Nameplate photo ───
                    if (ticket.nameplatePhotoUrl != null &&
                        ticket.nameplatePhotoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Nameplate'),
                      const SizedBox(height: 8),
                      _PhotoCard(
                        child: TicketNetworkPhotoPreview(
                          imageUrl: ticket.nameplatePhotoUrl!,
                          title: 'Nameplate photo',
                        ),
                      ),
                    ],

                    // ─── Dashboard photo ───
                    if (ticket.dashboardPhotoUrl != null &&
                        ticket.dashboardPhotoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Dashboard (Machine Hours)'),
                      const SizedBox(height: 8),
                      _PhotoCard(
                        child: TicketNetworkPhotoPreview(
                          imageUrl: ticket.dashboardPhotoUrl!,
                          title: 'Dashboard photo',
                        ),
                      ),
                    ],

                    // ─── Issue photo ───
                    if (ticket.photoUrl != null &&
                        ticket.photoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Photo of Issue'),
                      const SizedBox(height: 8),
                      _PhotoCard(
                        child: TicketNetworkPhotoPreview(
                          imageUrl: ticket.photoUrl!,
                          title: 'Issue photo',
                        ),
                      ),
                    ],

                    // ─── Damaged parts photos ───
                    if (ticket.damagePhotos != null &&
                        ticket.damagePhotos!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Damaged Parts'),
                      const SizedBox(height: 8),
                      ...ticket.damagePhotos!.where((p) => p.photoUrl.isNotEmpty).expand(
                        (p) => [
                          _PhotoCard(
                            child: TicketNetworkPhotoPreview(
                              imageUrl: p.photoUrl,
                              title: 'Damage photo',
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
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
                            if (ticket.serviceCharge != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFE082)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.payments_rounded, size: 18, color: Color(0xFFF9A825)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Service Charge',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF795548)),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '₱${ticket.serviceCharge!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFF57F17),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                        _PhotoCard(
                          child: TicketNetworkPhotoPreview(
                            imageUrl: ticket.resolutionPhotoUrl!,
                            title: 'Resolution photo',
                          ),
                        ),
                      ],
                    ],

                    // ─── Discussion hint (hidden when resolved) ───
                    if (ticket.status != 'resolved' &&
                        ticket.status != 'closed') ...[
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
                    ],

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

// ─── Resolve Bottom Sheet ────────────────────────

class _ResolveSheet extends StatefulWidget {
  const _ResolveSheet({
    required this.ticketId,
    required this.onResolved,
    this.ticket,
  });

  final int ticketId;
  final VoidCallback onResolved;
  final Ticket? ticket;

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  final _findingsController = TextEditingController();
  final _jobDoneController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _remarksController = TextEditingController();
  final _chargeController = TextEditingController();
  final _downPaymentController = TextEditingController();
  File? _newPhoto; // newly picked service report photo
  String? _existingPhotoUrl; // existing resolution photo URL from server

  bool get _hasPhoto => _newPhoto != null || _existingPhotoUrl != null;

  final List<File> _newDrPhotos = []; // newly picked DR photos
  List<String> _existingDrPhotoUrls = []; // existing DR photo URLs from server
  bool _submitting = false;
  int? _installments;
  final _partialReasonController = TextEditingController();

  // Parts
  List<TractorPart> _availableParts = [];
  final List<_ResolveSelectedPart> _selectedParts = [];
  bool _loadingParts = false;
  List<TicketTractorPart>? _pendingParts;

  // Track current search text per part row for "Add new" detection
  final List<String> _partSearchTexts = [];

  @override
  void initState() {
    super.initState();

    final ticket = widget.ticket;
    if (ticket != null) {
      // Pre-fill service charge
      if (ticket.serviceCharge != null) {
        _chargeController.text = ticket.serviceCharge!.toStringAsFixed(2);
      }
      // Pre-fill down payment
      if (ticket.downPayment != null) {
        _downPaymentController.text = ticket.downPayment!.toStringAsFixed(2);
      }
      // Pre-fill installments
      _installments = ticket.installments;

      // Restore existing resolution photo URL
      if (ticket.resolutionPhotoUrl != null && ticket.resolutionPhotoUrl!.isNotEmpty) {
        _existingPhotoUrl = ticket.resolutionPhotoUrl;
      }
      // Restore existing DR photo URLs
      if (ticket.drPhotoUrls != null && ticket.drPhotoUrls!.isNotEmpty) {
        _existingDrPhotoUrls = List<String>.from(ticket.drPhotoUrls!);
      }

      // Pre-fill parts (will be matched after fetchParts loads)
      if (ticket.tractorParts != null && ticket.tractorParts!.isNotEmpty) {
        _pendingParts = ticket.tractorParts;
      }

      // Parse resolution notes into findings/job done/recommendation/remarks
      if (ticket.resolutionNotes != null && ticket.resolutionNotes!.isNotEmpty) {
        _parseResolutionNotes(ticket.resolutionNotes!);
      }
    }

    _fetchParts();
  }

  Future<void> _fetchParts() async {
    setState(() => _loadingParts = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: {
          'Authorization': 'Bearer ${context.read<AuthProvider>().session?.token ?? ''}',
          'Accept': 'application/json',
        },
      ));
      final response = await dio.get('/tractor-parts');
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        _availableParts = data
            .map<TractorPart>((e) => TractorPart.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Match pending parts from existing ticket data
      if (_pendingParts != null && _availableParts.isNotEmpty) {
        for (final tp in _pendingParts!) {
          final match = _availableParts.firstWhere(
            (p) => p.name == tp.name,
            orElse: () => TractorPart(id: -1, name: tp.name, amount: tp.amount),
          );
          _selectedParts.add(_ResolveSelectedPart(part: match, amount: tp.amount.toStringAsFixed(2)));
          _selectedParts.last.quantityController.text = tp.quantity.toString();
          _partSearchTexts.add(match.name);
        }
        _pendingParts = null;
      }
    } catch (_) { /* silent */ }
    if (mounted) setState(() => _loadingParts = false);
  }

  void _parseResolutionNotes(String notes) {
    final lines = notes.split('\n');
    for (final line in lines) {
      if (line.startsWith('Findings: ')) {
        _findingsController.text = line.substring('Findings: '.length);
      } else if (line.startsWith('Job Done: ')) {
        _jobDoneController.text = line.substring('Job Done: '.length);
      } else if (line.startsWith('Recommendation: ')) {
        _recommendationController.text = line.substring('Recommendation: '.length);
      } else if (line.startsWith('Remarks: ')) {
        _remarksController.text = line.substring('Remarks: '.length);
      }
    }
  }

  void _addPartRow() {
    if (_availableParts.isEmpty) return;
    setState(() {
      _selectedParts.add(_ResolveSelectedPart(part: _availableParts.first));
      _partSearchTexts.add(_availableParts.first.name);
    });
  }

  void _removePartRow(int index) {
    setState(() {
      _selectedParts[index].dispose();
      _selectedParts.removeAt(index);
      _partSearchTexts.removeAt(index);
    });
  }

  double get _partsSubtotal {
    double total = 0;
    for (final sp in _selectedParts) {
      total += sp.lineTotal;
    }
    return total;
  }

  double get _totalAmount {
    double total = double.tryParse(_chargeController.text) ?? 0;
    total += _partsSubtotal;
    return total;
  }

  double get _balance =>
      _totalAmount - (double.tryParse(_downPaymentController.text) ?? 0);

  double get _perInstallment {
    if (_installments == null || _installments! <= 0 || _balance <= 0) {
      return 0;
    }
    return _balance / _installments!;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _newPhoto = File(picked.path));
    }
  }

  Future<void> _pickDrFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _newDrPhotos.add(File(picked.path)));
    }
  }

  Future<void> _pickDrFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _newDrPhotos.add(File(picked.path)));
    }
  }

  void _showPartialReasonDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pending_rounded, color: Color(0xFFE65100), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Partial Resolve', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        SizedBox(height: 2),
                        Text('Why is this not yet fully resolved?', style: TextStyle(fontSize: 13, color: AppColors.mutedInk)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _partialReasonController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Waiting for parts delivery, need additional tools, pending customer approval...',
                  hintStyle: TextStyle(color: AppColors.mutedInk.withValues(alpha: 0.5), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F6),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mutedInk,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final reason = _partialReasonController.text.trim();
                        if (reason.isNotEmpty) {
                          final existing = _findingsController.text;
                          _findingsController.text = existing.isEmpty
                            ? 'Partial Reason: $reason'
                            : 'Partial Reason: $reason\n$existing';
                        }
                        _submit(partial: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Continue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit({bool partial = false}) async {
    setState(() => _submitting = true);

    final chargeText = _chargeController.text.trim();
    final serviceCharge = chargeText.isNotEmpty ? double.tryParse(chargeText) : null;
    final downPayment = double.tryParse(_downPaymentController.text);

    final parts = _selectedParts
        .where((sp) => double.tryParse(sp.amountController.text) != null)
        .map((sp) {
          final data = <String, dynamic>{
            'amount': double.parse(sp.amountController.text),
            'quantity': int.tryParse(sp.quantityController.text) ?? 1,
          };
          if (sp.isNew) {
            data['name'] = sp.part.name;
          } else {
            data['id'] = sp.part.id;
          }
          return data;
        })
        .toList();

    final success = await context.read<TicketProvider>().resolveTicket(
      ticketId: widget.ticketId,
      resolutionNotes: (() {
        final notes = [
          if (_findingsController.text.trim().isNotEmpty) 'Findings: ${_findingsController.text.trim()}',
          if (_jobDoneController.text.trim().isNotEmpty) 'Job Done: ${_jobDoneController.text.trim()}',
          if (_recommendationController.text.trim().isNotEmpty) 'Recommendation: ${_recommendationController.text.trim()}',
          if (_remarksController.text.trim().isNotEmpty) 'Remarks: ${_remarksController.text.trim()}',
        ];
        return notes.isNotEmpty ? notes.join('\n') : null;
      })(),
      resolutionPhoto: _newPhoto,
      serviceCharge: serviceCharge,
      downPayment: downPayment,
      installments: _installments,
      partial: partial,
      parts: parts,
      drPhotos: _newDrPhotos.isNotEmpty ? _newDrPhotos : null,
      keepDrPhotos: _existingDrPhotoUrls.isNotEmpty ? _existingDrPhotoUrls : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context);
      AppToast.show(partial ? 'Progress updated' : 'Ticket resolved successfully');
      widget.onResolved();
    } else {
      AppToast.show('Failed to resolve ticket', type: ToastType.error);
    }
  }

  @override
  void dispose() {
    _findingsController.dispose();
    _jobDoneController.dispose();
    _recommendationController.dispose();
    _remarksController.dispose();
    _chargeController.dispose();
    _downPaymentController.dispose();
    _partialReasonController.dispose();
    for (final sp in _selectedParts) {
      sp.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.mutedInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Resolve Ticket',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add resolution notes and a photo proof that the issue is fixed.',
            style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
          ),
          const SizedBox(height: 18),

          // ─── Tractor Parts ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tractor Parts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
              TextButton.icon(
                onPressed: _loadingParts ? null : _addPartRow,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Part'),
                style: TextButton.styleFrom(foregroundColor: AppColors.forest, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (_selectedParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate(_selectedParts.length, (i) {
              final sp = _selectedParts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Search autocomplete + Qty + Amount + Remove
                      Row(
                        children: [
                          // Searchable part picker
                          Expanded(
                            flex: 3,
                            child: Autocomplete<TractorPart>(
                              initialValue: TextEditingValue(text: sp.part.name),
                              optionsBuilder: (textEditingValue) {
                                _partSearchTexts[i] = textEditingValue.text;
                                if (_partSearchTexts[i].isEmpty) {
                                  return _availableParts;
                                }
                                final query = _partSearchTexts[i].toLowerCase();
                                return _availableParts.where(
                                  (p) => p.name.toLowerCase().contains(query),
                                );
                              },
                              fieldViewBuilder: (
                                context,
                                fieldController,
                                focusNode,
                                onSubmitted,
                              ) {
                                return TextField(
                                  controller: fieldController,
                                  focusNode: focusNode,
                                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                                  decoration: InputDecoration(
                                    hintText: 'Search parts...',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mutedInk.withValues(alpha: 0.5),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
                                    ),
                                  ),
                                );
                              },
                              displayStringForOption: (option) => option.name,
                              onSelected: (part) {
                                setState(() {
                                  sp.part = part;
                                  sp.amountController.text = part.amount?.toString() ?? '';
                                });
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                final opts = options.toList();
                                final searchText = _partSearchTexts[i];
                                final showAddNew = searchText.isNotEmpty &&
                                    !_availableParts.any(
                                      (p) => p.name.toLowerCase() == searchText.toLowerCase(),
                                    );
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: opts.length + (showAddNew ? 1 : 0),
                                        itemBuilder: (ctx, idx) {
                                          if (showAddNew && idx == opts.length) {
                                            return ListTile(
                                              leading: const Icon(Icons.add_rounded, color: AppColors.forest, size: 20),
                                              title: Text(
                                                'Add "$searchText"',
                                                style: const TextStyle(
                                                  color: AppColors.forest,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              onTap: () {
                                                final newPart = TractorPart(
                                                  id: -1 * ((DateTime.now().millisecondsSinceEpoch % 100000) + i + 1),
                                                  name: searchText,
                                                  amount: 0,
                                                );
                                                setState(() {
                                                  sp.part = newPart;
                                                  sp.amountController.text = '0';
                                                  _partSearchTexts[i] = searchText;
                                                });
                                              },
                                            );
                                          }
                                          final part = opts[idx];
                                          return ListTile(
                                            title: Text(part.name, style: const TextStyle(fontSize: 13)),
                                            subtitle: part.amount != null
                                                ? Text(
                                                    'Base price: ₱${part.amount!.toStringAsFixed(2)}',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
                                                  )
                                                : null,
                                            onTap: () {
                                              onSelected(part);
                                              _partSearchTexts[i] = part.name;
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quantity
                          SizedBox(
                            width: 44,
                            child: TextFormField(
                              controller: sp.quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: '1',
                                hintStyle: TextStyle(fontSize: 12, color: AppColors.mutedInk.withValues(alpha: 0.4)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Amount
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: sp.amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                prefixText: '₱ ',
                                prefixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                hintText: '0.00',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Remove button
                          GestureDetector(
                            onTap: () => _removePartRow(i),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                      // Row 2: Price per unit + Line total
                      if (sp.part.amount != null || sp.amountController.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Price per unit: ₱${(double.tryParse(sp.amountController.text) ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
                            ),
                            const Spacer(),
                            Text(
                              'Total: ₱${sp.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            // Subtotal row
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Subtotal: ', style: TextStyle(fontSize: 13, color: AppColors.mutedInk)),
                  Text('₱${_partsSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.forest)),
                ],
              ),
            ),
          ],

          // ─── Service charge ───
          Row(
            children: [
              const Text('Service Charge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink)),
              const Spacer(),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _chargeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    prefixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    hintText: '0.00',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Payment Plan ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_rounded,
                        size: 18, color: Color(0xFFF9A825)),
                    const SizedBox(width: 6),
                    const Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF795548),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₱${_totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Service Charge',
                        style: TextStyle(fontSize: 12, color: Color(0xFF795548)),
                      ),
                    ),
                    Text(
                      '₱${(double.tryParse(_chargeController.text) ?? 0).toStringAsFixed(2)}',
                      style:
                          const TextStyle(fontSize: 12, color: Color(0xFF795548)),
                    ),
                  ],
                ),
                if (_partsSubtotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Parts',
                            style:
                                TextStyle(fontSize: 12, color: Color(0xFF795548)),
                          ),
                        ),
                        Text(
                          '₱${_partsSubtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF795548)),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Color(0xFFFFE082), height: 16),
                TextFormField(
                  controller: _downPaymentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    prefixStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF795548),
                    ),
                    hintText: '0.00',
                    labelText: 'Down Payment',
                    hintStyle: TextStyle(
                      color: const Color(0xFF795548).withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFFFDE7),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFE082)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFE082)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFF9A825), width: 1.5),
                    ),
                  ),
                ),
                if ((double.tryParse(_downPaymentController.text) ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Balance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF795548),
                          ),
                        ),
                      ),
                      Text(
                        '₱${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _installments,
                      isExpanded: true,
                      hint: const Text(
                        'Full Payment',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF795548),
                        ),
                      ),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF795548)),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Full Payment'),
                        ),
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem<int?>(
                            value: m,
                            child: Text('$m Month${m > 1 ? 's' : ''}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _installments = v),
                    ),
                  ),
                ),
                if (_installments != null &&
                    _installments! > 0 &&
                    _balance > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Per Installment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF795548),
                          ),
                        ),
                      ),
                      Text(
                        '₱${_perInstallment.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_installments monthly payment${_installments! > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFA1887F),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Findings ───
          const Text('Findings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _findingsController,
            maxLines: 2,
            decoration: _partFieldDecoration('What was found...'),
          ),
          const SizedBox(height: 12),

          // ─── Job Done ───
          const Text('Job Done', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _jobDoneController,
            maxLines: 2,
            decoration: _partFieldDecoration('What work was completed...'),
          ),
          const SizedBox(height: 12),

          // ─── Recommendation ───
          const Text('Recommendation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _recommendationController,
            maxLines: 2,
            decoration: _partFieldDecoration('Suggested actions...'),
          ),
          const SizedBox(height: 12),

          // ─── Remarks ───
          const Text('Remarks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _remarksController,
            maxLines: 2,
            decoration: _partFieldDecoration('Additional notes...'),
          ),
          const SizedBox(height: 14),

          // ─── Service Report Photo ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Service Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: double.infinity,
                    height: _hasPhoto ? 160 : 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _hasPhoto
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: _newPhoto != null
                                    ? Image.file(
                                        _newPhoto!,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        _existingPhotoUrl!,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.broken_image_rounded, size: 40, color: AppColors.mutedInk),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setState(() { _newPhoto = null; _existingPhotoUrl = null; }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 20,
                                color: AppColors.mutedInk.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Take service report photo',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── DR/SI/CR Photos ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DR / SI / CR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    Text('${_existingDrPhotoUrls.length + _newDrPhotos.length}/3', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_existingDrPhotoUrls.isNotEmpty || _newDrPhotos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...List.generate(_existingDrPhotoUrls.length, (i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _existingDrPhotoUrls[i],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image_rounded, size: 24, color: AppColors.mutedInk),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _existingDrPhotoUrls.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      ...List.generate(_newDrPhotos.length, (i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _newDrPhotos[i],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _newDrPhotos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 28, color: AppColors.mutedInk.withValues(alpha: 0.4)),
                        const SizedBox(height: 4),
                        const Text('Upload DR, SI, or CR documents', style: TextStyle(fontSize: 12, color: AppColors.mutedInk)),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_existingDrPhotoUrls.length + _newDrPhotos.length) >= 3 ? null : _pickDrFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_existingDrPhotoUrls.length + _newDrPhotos.length) >= 3 ? null : _pickDrFromCamera,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => _showPartialReasonDialog(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE65100),
                      side: const BorderSide(color: Color(0xFFFFCC80)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Partial Resolve'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(partial: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.success.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Mark as Resolved'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: AppColors.ink,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _partFieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.mutedInk.withValues(alpha: 0.5), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF5F7F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
      ),
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
    final (Color bg, Color fg, IconData icon) = switch (status) {
      'open' => (const Color(0xFFE8F5E9), AppColors.forest, Icons.fiber_manual_record_rounded),
      'in_progress' => (const Color(0xFFFFF3E0), const Color(0xFFE65100), Icons.sync_rounded),
      'resolved' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0), Icons.check_circle_rounded),
      'closed' => (Colors.grey.shade100, AppColors.mutedInk, Icons.lock_rounded),
      _ => (Colors.grey.shade100, AppColors.mutedInk, Icons.help_outline_rounded),
    };

    final label = switch (status) {
      'open' => 'Open',
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ResolveSelectedPart {
  final TextEditingController quantityController;
  final TextEditingController amountController;
  TractorPart part;
  final bool isNew;

  _ResolveSelectedPart({required this.part, String? amount})
    : isNew = part.id < 0,
      quantityController = TextEditingController(text: '1'),
      amountController = TextEditingController(text: amount ?? '') {
    quantityController.addListener(_updateDisplay);
    amountController.addListener(_updateDisplay);
  }

  void _updateDisplay() {
    // Listeners will trigger parent rebuild via onChanged callbacks in fields.
  }

  double get lineTotal {
    final qty = int.tryParse(quantityController.text) ?? 1;
    final amt = double.tryParse(amountController.text) ?? 0;
    return qty * amt;
  }

  void dispose() {
    quantityController.removeListener(_updateDisplay);
    amountController.removeListener(_updateDisplay);
    quantityController.dispose();
    amountController.dispose();
  }
}
