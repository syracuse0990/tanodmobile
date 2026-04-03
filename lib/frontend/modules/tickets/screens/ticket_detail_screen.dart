import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/realtime_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/ticket.dart';
import 'package:tanodmobile/services/websocket/pusher_client.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  StreamSubscription<PusherEvent>? _eventSub;
  String _channelName = '';

  // Typing indicator state
  String? _typingUserName;
  String? _typingUserRole;
  Timer? _typingClearTimer;

  @override
  void initState() {
    super.initState();
    _channelName = 'private-ticket.${widget.ticketId}';

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
        context.read<TicketProvider>().appendRealtimeComment(commentData);
      }
    } else if (event.event == 'client-typing') {
      if (!mounted) return;
      setState(() {
        _typingUserName = event.data['name'] as String?;
        _typingUserRole = event.data['role'] as String?;
      });
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _typingUserName = null);
      });
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _typingClearTimer?.cancel();
    // Unsubscribe from the ticket channel
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
          context.read<TicketProvider>().fetchTicketDetail(widget.ticketId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    final ticket = provider.selectedTicket;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Ticket Details'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account/tickets'),
        ),
      ),
      bottomNavigationBar: ticket != null && ticket.isResolvable
          ? _ResolveBottomBar(onResolve: _showResolveSheet)
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
                    if (ticket.photoUrl != null) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Photo of Issue'),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          ticket.photoUrl!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.mutedInk,
                              ),
                            ),
                          ),
                        ),
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
                      if (ticket.resolutionPhotoUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            ticket.resolutionPhotoUrl!,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],

                    // ─── Chat Section ───
                    const SizedBox(height: 16),
                    _SectionHeader(title: 'Discussion'),
                    const SizedBox(height: 8),

                    if (ticket.comments != null && ticket.comments!.isNotEmpty)
                      ...ticket.comments!.map((c) {
                        final currentUserId = context
                            .read<AuthProvider>()
                            .currentUser
                            ?.id;
                        final isMe = c.userId == currentUserId;
                        return _ChatBubble(comment: c, isMe: isMe);
                      })
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No messages yet. Start the conversation.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ),
                      ),

                    // Typing indicator
                    if (_typingUserName != null)
                      _TypingIndicator(
                        userName: _typingUserName!,
                        userRole: _typingUserRole,
                      ),

                    // Inline chat input
                    const SizedBox(height: 8),
                    _ChatInput(
                      ticketId: widget.ticketId,
                      channelName: _channelName,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

String _formatCommentTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Resolve-only Bottom Bar ─────────────────────

class _ResolveBottomBar extends StatelessWidget {
  const _ResolveBottomBar({required this.onResolve});

  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.of(context).viewInsets.bottom + 10,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onResolve,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
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
      ),
    );
  }
}

// ─── Inline Chat Input ───────────────────────────

class _ChatInput extends StatefulWidget {
  const _ChatInput({required this.ticketId, required this.channelName});

  final int ticketId;
  final String channelName;

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  final _controller = TextEditingController();
  bool _sending = false;
  File? _selectedFile;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_controller.text.isEmpty) return;
    if (_typingDebounce?.isActive ?? false) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final roleName = _displayRole(user?.roles.firstOrNull ?? '');

    context.read<RealtimeProvider>().triggerClientEvent(
      widget.channelName,
      'client-typing',
      {'name': user?.name ?? 'Someone', 'role': roleName},
    );

    _typingDebounce = Timer(const Duration(seconds: 2), () {});
  }

  String _displayRole(String role) {
    return switch (role) {
      'super-admin' || 'sub-admin' => 'Admin',
      'tps' => 'TPS',
      'fca' => 'FCA',
      'farmer' => 'Farmer',
      _ => '',
    };
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedFile = File(picked.path));
    }
  }

  void _removeAttachment() {
    setState(() => _selectedFile = null);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    if (_sending) return;

    setState(() => _sending = true);

    final success = await context.read<TicketProvider>().addComment(
      ticketId: widget.ticketId,
      body: text.isEmpty ? null : text,
      attachment: _selectedFile,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (success) {
      _controller.clear();
      setState(() => _selectedFile = null);
    } else {
      AppToast.show('Failed to send message', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment preview
          if (_selectedFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _selectedFile!,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _removeAttachment,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Input row
          Row(
            children: [
              // Attachment button
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  onPressed: _pickAttachment,
                  icon: const Icon(Icons.attach_file_rounded, size: 20),
                  color: AppColors.mutedInk,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 4),
              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Write your message...',
                    hintStyle: TextStyle(
                      color: AppColors.mutedInk.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              SizedBox(
                width: 40,
                height: 40,
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: AppColors.forest,
                          strokeWidth: 2.5,
                        ),
                      )
                    : IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded, size: 20),
                        color: AppColors.forest,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.forest.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
              ),
            ],
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
  File? _photo;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
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

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final success = await context.read<TicketProvider>().resolveTicket(
      ticketId: widget.ticketId,
      resolutionNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      resolutionPhoto: _photo,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
          Text(
            'Add resolution notes and a photo proof that the issue is fixed.',
            style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
          ),
          const SizedBox(height: 18),

          // Resolution notes
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
          const SizedBox(height: 14),

          // Photo proof
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
                        Text(
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

          // Submit button
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
        ],
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

// ─── Animated typing dots ───────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.userName, this.userRole});

  final String userName;
  final String? userRole;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = '${widget.userRole ?? ''} ${widget.userName} is typing...'
        .trimLeft();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final shift = i * 0.25;
                final t = ((_anim.value + shift) % 1.0);
                final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : 2.0 - t * 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat bubble ────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.comment, required this.isMe});

  final TicketComment comment;
  final bool isMe;

  bool get _hasAttachment =>
      comment.attachmentUrl != null && comment.attachmentUrl!.isNotEmpty;

  bool get _isImageAttachment {
    if (!_hasAttachment) return false;
    final url = comment.attachmentUrl!.toLowerCase();
    return url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp');
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                comment.attachmentUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, size: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (comment.userName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.forest.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  if (!isMe)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name + time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMe ? 'You' : (comment.userName ?? 'User'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMe ? AppColors.forest : AppColors.mutedInk,
                        ),
                      ),
                      if (comment.createdAt != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          _formatCommentTime(comment.createdAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedInk.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Attachment image
                  if (_hasAttachment && _isImageAttachment) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showFullImage(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          comment.attachmentUrl!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.mutedInk,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Non-image attachment
                  if (_hasAttachment && !_isImageAttachment) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forest.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 18,
                            color: AppColors.forest,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Attachment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Message body
                  if (comment.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      comment.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
