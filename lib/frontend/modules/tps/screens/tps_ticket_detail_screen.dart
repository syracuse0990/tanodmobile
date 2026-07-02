import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/chat/widgets/ticket_conversation_sheet.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_network_photo_preview.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/chat_unread_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/realtime_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/services/websocket/pusher_client.dart';

class TpsTicketDetailScreen extends StatefulWidget {
  const TpsTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.backLocation = '/tps',
    this.openChatOnLoad = false,
  });

  final int ticketId;
  final String backLocation;
  final bool openChatOnLoad;

  @override
  State<TpsTicketDetailScreen> createState() => _TpsTicketDetailScreenState();
}

class _TpsTicketDetailScreenState extends State<TpsTicketDetailScreen> {
  StreamSubscription<PusherEvent>? _eventSub;
  String _channelName = '';

  final _typingUserName = ValueNotifier<String?>(null);
  final _typingUserRole = ValueNotifier<String?>(null);
  Timer? _typingClearTimer;

  int _unreadCount = 0;
  bool _chatOpen = false;
  bool _didAutoOpenChat = false;

  @override
  void initState() {
    super.initState();
    _channelName = 'private-ticket.${widget.ticketId}';
    debugPrint(
      'TpsTicketDetailScreen: subscribing to realtime room $_channelName',
    );

    context.read<TpsProvider>().fetchTicketDetail(widget.ticketId);

    final realtime = context.read<RealtimeProvider>();
    realtime.subscribeToChannel(_channelName);
    _eventSub = realtime.events?.listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(PusherEvent event) {
    if (event.channel != _channelName) return;

    if (event.event.contains('TicketCommentAdded')) {
      final commentData = event.data['comment'] as Map<String, dynamic>?;
      if (commentData != null && mounted) {
        debugPrint(
          'TpsTicketDetailScreen: received comment event on $_channelName '
          'commentId=${commentData['id']} chatOpen=$_chatOpen',
        );
        context.read<TpsProvider>().appendRealtimeComment(commentData);
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
        'TpsTicketDetailScreen: received typing event on $_channelName '
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
      'TpsTicketDetailScreen: unsubscribing from realtime room $_channelName',
    );
    context.read<RealtimeProvider>().unsubscribeFromChannel(_channelName);
    super.dispose();
  }

  void _showResolveSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ResolveSheet(
        ticketId: widget.ticketId,
        onResolved: () {
          context.read<TpsProvider>().fetchTicketDetail(widget.ticketId);
        },
      ),
    );
  }

  void _showCloseConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Ticket'),
        content: const Text(
          'Are you sure you want to close this ticket? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.mutedInk),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<TpsProvider>().closeTicket(
                widget.ticketId,
              );
              if (mounted) {
                if (success) {
                  AppToast.show('Ticket closed');
                } else {
                  AppToast.show(
                    'Failed to close ticket',
                    type: ToastType.error,
                  );
                }
              }
            },
            child: const Text(
              'Close Ticket',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssistanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssistanceSheet(ticketId: widget.ticketId),
    );
  }

  void _openChat() {
    final chatUnreadProvider = context.read<ChatUnreadProvider>();

    setState(() {
      _unreadCount = 0;
      _chatOpen = true;
    });

    chatUnreadProvider.setActiveTicketId(widget.ticketId);

    final provider = context.read<TpsProvider>();
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
    final provider = context.watch<TpsProvider>();
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
                                    style: const TextStyle(
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
                              style: const TextStyle(
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

                    // ─── Action buttons ───
                    if (ticket.isResolvable) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _showResolveSheet,
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20,
                                ),
                                label: const Text('Resolve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _showCloseConfirm,
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 20,
                                ),
                                label: const Text('Close'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.mutedInk,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showAssistanceSheet,
                          icon: const Icon(Icons.sos_rounded, size: 20),
                          label: const Text('Request Assistance'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.clay,
                            side: const BorderSide(color: AppColors.clay),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ─── Resolved-only: close + assistance ───
                    if (ticket.status == 'resolved') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showCloseConfirm,
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: const Text('Close Ticket'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedInk,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ─── Issue photo ───
                    if (ticket.photoUrl != null &&
                        ticket.photoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionHeader(title: 'Photo of Issue'),
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
                      const _SectionHeader(title: 'Resolution'),
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
                                style: const TextStyle(
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
                                    style: const TextStyle(
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

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Request Assistance Bottom Sheet ─────────────

class _AssistanceSheet extends StatefulWidget {
  const _AssistanceSheet({required this.ticketId});

  final int ticketId;

  @override
  State<_AssistanceSheet> createState() => _AssistanceSheetState();
}

class _AssistanceSheetState extends State<_AssistanceSheet> {
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      AppToast.show(
        'Please describe what assistance you need',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _submitting = true);

    final success = await context.read<TpsProvider>().requestAssistance(
      ticketId: widget.ticketId,
      message: msg,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context);
      AppToast.show('Assistance request sent to admin');
    } else {
      AppToast.show('Failed to send request', type: ToastType.error);
    }
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Request Assistance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Describe what you need — parts for repair, additional hands, tools, etc. Admin will be notified via notification and SMS.',
            style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'e.g. Need replacement belt for tractor engine, requesting repair tools...',
              hintStyle: TextStyle(
                color: AppColors.mutedInk.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7F6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.forest,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.shrink()
                  : const Icon(Icons.send_rounded, size: 20),
              label: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Send Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clay,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.clay.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resolve Bottom Sheet ────────────────────────

class _ResolveSheet extends StatefulWidget {
  const _ResolveSheet({required this.ticketId, required this.onResolved});

  final int ticketId;
  final VoidCallback onResolved;

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  final _notesController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  final _downPaymentController = TextEditingController();
  File? _photo;
  bool _submitting = false;
  bool _loadingParts = false;

  // Parts
  List<Map<String, dynamic>> _availableParts = [];
  Map<String, dynamic>? _selectedPart;
  final _partQtyController = TextEditingController(text: '1');
  final List<Map<String, dynamic>> _parts = [];

  // Installments dropdown
  int? _selectedInstallments;

  // DR photos
  final List<File> _drPhotos = [];

  // Payment type: 'full' or 'installment'
  String _paymentType = 'full';

  // ── Computed totals ──
  double get _partsTotal {
    return _parts.fold<double>(0, (sum, p) {
      final amt = (p['amount'] is num)
          ? (p['amount'] as num).toDouble()
          : double.tryParse(p['amount']?.toString() ?? '') ?? 0;
      final qty = (p['quantity'] is num)
          ? (p['quantity'] as num).toDouble()
          : double.tryParse(p['quantity']?.toString() ?? '') ?? 1;
      return sum + amt * qty;
    });
  }

  double get _serviceCharge {
    return double.tryParse(_serviceChargeController.text.trim()) ?? 0;
  }

  double get _totalAmount => _serviceCharge + _partsTotal;

  double get _downPayment {
    return double.tryParse(_downPaymentController.text.trim()) ?? 0;
  }

  double? get _monthlyPayment {
    if (_paymentType != 'installment' || _selectedInstallments == null || _selectedInstallments! <= 0) return null;
    final balance = _totalAmount - _downPayment;
    if (balance <= 0) return 0;
    return balance / _selectedInstallments!;
  }

  @override
  void initState() {
    super.initState();
    _fetchParts();
  }

  Future<void> _fetchParts() async {
    setState(() => _loadingParts = true);
    final provider = context.read<TpsProvider>();
    await provider.fetchTractorParts();
    setState(() {
      _availableParts = provider.tractorParts;
      _loadingParts = false;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _serviceChargeController.dispose();
    _downPaymentController.dispose();
    _partQtyController.dispose();
    super.dispose();
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
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _pickDrPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null && _drPhotos.length < 3) {
      setState(() => _drPhotos.add(File(picked.path)));
    }
  }

  void _addPart() {
    if (_selectedPart == null) return;
    final qty = int.tryParse(_partQtyController.text.trim()) ?? 1;
    final amount = (_selectedPart!['amount'] is num)
        ? (_selectedPart!['amount'] as num).toDouble()
        : double.tryParse(_selectedPart!['amount'].toString()) ?? 0;
    setState(() {
      _parts.add({
        'id': _selectedPart!['id'],
        'name': _selectedPart!['name'],
        'amount': amount,
        'quantity': qty,
      });
      _selectedPart = null;
      _partQtyController.text = '1';
    });
  }

  void _removePart(int index) {
    setState(() => _parts.removeAt(index));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final success = await context.read<TpsProvider>().resolveTicket(
      ticketId: widget.ticketId,
      resolutionNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      resolutionPhoto: _photo,
      serviceCharge: double.tryParse(_serviceChargeController.text.trim()),
      downPayment: double.tryParse(_downPaymentController.text.trim()),
      installments: _selectedInstallments,
      parts: _parts.isNotEmpty ? _parts : null,
      drPhotos: _drPhotos.isNotEmpty ? _drPhotos : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context);
      AppToast.show('Ticket resolved successfully');
      widget.onResolved();
    } else {
      AppToast.show('Failed to resolve ticket', type: ToastType.error);
    }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
            const Text(
              'Add resolution details, billing info and photo proof.',
              style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
            ),
            const SizedBox(height: 18),

            // ── Resolution notes ──
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Resolution notes (optional)',
                hintStyle: TextStyle(
                  color: AppColors.mutedInk.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F7F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.forest,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Resolution Photo ──
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: _photo != null ? 160 : 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _photo != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(
                              _photo!,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(() => _photo = null),
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
                            size: 22,
                            color: AppColors.mutedInk.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Take photo proof',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Billing Section ──
            const Text(
              'Billing',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),

            // Service Charge
            TextFormField(
              controller: _serviceChargeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Service / Labor Charge',
                prefixText: '₱ ',
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: AppColors.mutedInk.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F7F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.forest,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Parts Section ──
            const Text(
              'Parts Used',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            // Parts list
            ..._parts.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₱${p['amount']} × ${p['quantity']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removePart(i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Add part form
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedPart,
                        isExpanded: true,
                        hint: Text(
                          _loadingParts ? 'Loading...' : 'Select part',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedInk.withValues(alpha: 0.5),
                          ),
                        ),
                        items: _availableParts.map((p) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: p,
                            child: Text(
                              '${p['name']}  (₱${p['amount']})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedPart = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    controller: _partQtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Qty',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF5F7F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _selectedPart != null ? _addPart : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedPart != null
                          ? AppColors.forest
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: _selectedPart != null ? Colors.white : Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Total Amount ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.forest.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  Text(
                    '₱${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Payment Type ──
            const Text(
              'Payment',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _paymentType = 'full';
                      _selectedInstallments = null;
                      _downPaymentController.clear();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentType == 'full'
                            ? AppColors.success
                            : const Color(0xFFF5F7F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paymentType == 'full'
                              ? AppColors.success
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Full Payment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _paymentType == 'full'
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentType = 'installment'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentType == 'installment'
                            ? AppColors.forest
                            : const Color(0xFFF5F7F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paymentType == 'installment'
                              ? AppColors.forest
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Installment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _paymentType == 'installment'
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Installment options ──
            if (_paymentType == 'installment') ...[
              const SizedBox(height: 12),

              // Installments dropdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedInstallments,
                    isExpanded: true,
                    hint: Text(
                      'Number of months',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedInk.withValues(alpha: 0.5),
                      ),
                    ),
                    items: List.generate(12, (i) => i + 1).map((m) {
                      return DropdownMenuItem<int>(
                        value: m,
                        child: Text('$m month${m > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 14, color: AppColors.ink),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedInstallments = v),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Down Payment
              TextFormField(
                controller: _downPaymentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Down Payment',
                  prefixText: '₱ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: AppColors.mutedInk.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.forest,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Monthly payment display
              if (_selectedInstallments != null && _totalAmount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.forest.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Payment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest,
                            ),
                          ),
                          Text(
                            _monthlyPayment != null
                                ? '₱${_monthlyPayment!.toStringAsFixed(2)}'
                                : '—',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forest,
                            ),
                          ),
                        ],
                      ),
                      if (_downPayment > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_selectedInstallments mos. × ₱${(_monthlyPayment ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedInk,
                              ),
                            ),
                            Text(
                              '= ₱${((_monthlyPayment ?? 0) * _selectedInstallments!).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 20),

            // ── DR Photos Section ──
            const Text(
              'DR / SI / CR Photos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _drPhotos.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == _drPhotos.length) {
                    return GestureDetector(
                      onTap: _drPhotos.length < 3 ? _pickDrPhoto : null,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _drPhotos.length < 3
                                ? Colors.grey.shade300
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 28,
                            color: _drPhotos.length < 3
                                ? AppColors.mutedInk.withValues(alpha: 0.5)
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _drPhotos[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _drPhotos.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Submit Button ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.success.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
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
            const SizedBox(height: 8),
          ],
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
    final ticket = context.watch<TpsProvider>().selectedTicket;
    final currentComments = ticket?.comments ?? comments;
    final currentUser = context.read<AuthProvider>().currentUser;

    return TicketConversationSheet(
      comments: currentComments,
      typingUserName: typingUserName,
      typingUserRole: typingUserRole,
      currentUserId: currentUser?.id,
      onSendComment: ({body, attachment}) {
        return context.read<TpsProvider>().addComment(
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
            style: const TextStyle(fontSize: 13, color: AppColors.mutedInk),
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
