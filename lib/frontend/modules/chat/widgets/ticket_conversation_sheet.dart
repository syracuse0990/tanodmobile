import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/ticket.dart';

typedef TicketChatSendComment =
    Future<bool> Function({String? body, File? attachment});

String formatTicketChatRole(String role) {
  return switch (role) {
    'super-admin' || 'sub-admin' => 'Admin',
    'tps' => 'TPS',
    'fca' => 'FCA',
    'farmer' => 'Farmer',
    _ => '',
  };
}

class TicketConversationSheet extends StatelessWidget {
  const TicketConversationSheet({
    super.key,
    required this.comments,
    required this.typingUserName,
    required this.typingUserRole,
    required this.currentUserId,
    required this.onSendComment,
    required this.onTyping,
  });

  final List<TicketComment> comments;
  final ValueNotifier<String?> typingUserName;
  final ValueNotifier<String?> typingUserRole;
  final int? currentUserId;
  final TicketChatSendComment onSendComment;
  final VoidCallback onTyping;

  @override
  Widget build(BuildContext context) {
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInsets),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFFF3F4EE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D6CF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE4E7E0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: AppColors.forest,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Discussion',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            comments.isEmpty
                                ? 'Shared room for ticket updates'
                                : '${comments.length} message${comments.length == 1 ? '' : 's'} in this room',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE4E7E0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.mutedInk,
                          size: 20,
                        ),
                        tooltip: 'Close discussion',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: const Color(0xFFE4E7E0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: comments.isNotEmpty
                              ? ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    20,
                                    16,
                                    20,
                                  ),
                                  itemCount: comments.length,
                                  itemBuilder: (context, index) {
                                    final comment =
                                        comments[comments.length - 1 - index];

                                    return _ConversationBubble(
                                      comment: comment,
                                      isMe: comment.userId == currentUserId,
                                    );
                                  },
                                )
                              : const _ConversationEmptyState(),
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: typingUserName,
                          builder: (context, name, _) {
                            if (name == null) {
                              return const SizedBox(height: 8);
                            }

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: _ConversationTypingIndicator(
                                userName: name,
                                userRole: typingUserRole.value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                child: _ConversationComposer(
                  onSendComment: onSendComment,
                  onTyping: onTyping,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2EF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 30,
                color: AppColors.mutedInk,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start the conversation with your support team here.',
              textAlign: TextAlign.center,
              style: TextStyle(
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

class _ConversationComposer extends StatefulWidget {
  const _ConversationComposer({
    required this.onSendComment,
    required this.onTyping,
  });

  final TicketChatSendComment onSendComment;
  final VoidCallback onTyping;

  @override
  State<_ConversationComposer> createState() => _ConversationComposerState();
}

class _ConversationComposerState extends State<_ConversationComposer> {
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
    if (_controller.text.trim().isEmpty) {
      return;
    }

    if (_typingDebounce?.isActive ?? false) {
      return;
    }

    widget.onTyping();
    _typingDebounce = Timer(const Duration(seconds: 2), () {});
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _selectedFile == null) || _sending) {
      return;
    }

    setState(() => _sending = true);

    final success = await widget.onSendComment(
      body: text.isEmpty ? null : text,
      attachment: _selectedFile,
    );

    if (!mounted) {
      return;
    }

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
        color: const Color(0xFFE9FFF7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD4F8EC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    _selectedFile!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFile = null),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.forest, width: 1.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: _pickAttachment,
                    icon: const Icon(Icons.attach_file_rounded, size: 20),
                    color: AppColors.mutedInk,
                    splashRadius: 20,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 1,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Write your message...',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: AppColors.mutedInk,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
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
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 17,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTypingIndicator extends StatefulWidget {
  const _ConversationTypingIndicator({required this.userName, this.userRole});

  final String userName;
  final String? userRole;

  @override
  State<_ConversationTypingIndicator> createState() =>
      _ConversationTypingIndicatorState();
}

class _ConversationTypingIndicatorState
    extends State<_ConversationTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = '${widget.userRole ?? ''} ${widget.userName} is typing...'
        .trimLeft();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (_, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final shift = index * 0.25;
                  final t = ((_animationController.value + shift) % 1.0);
                  final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : 2.0 - t * 2);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.forest,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.mutedInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({required this.comment, required this.isMe});

  final TicketComment comment;
  final bool isMe;

  bool get _hasAttachment =>
      comment.attachmentUrl != null && comment.attachmentUrl!.isNotEmpty;

  bool get _isImageAttachment {
    if (!_hasAttachment) {
      return false;
    }

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
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  comment.attachmentUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 48),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2EF),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Center(
                child: Text(
                  (comment.userName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * (isMe ? 0.46 : 0.67),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFE4ECE8) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isMe ? 22 : 10),
                  bottomRight: Radius.circular(isMe ? 10 : 22),
                ),
                border: Border.all(
                  color: isMe
                      ? const Color(0xFFD2DDD7)
                      : const Color(0xFFE7EBE5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? 'You' : (comment.userName ?? 'User'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isMe ? AppColors.forest : AppColors.mutedInk,
                          ),
                        ),
                      ),
                      if (comment.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatConversationTime(comment.createdAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_hasAttachment) ...[
                    const SizedBox(height: 12),
                    if (_isImageAttachment)
                      GestureDetector(
                        onTap: () => _showFullImage(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            comment.attachmentUrl!,
                            width: double.infinity,
                            height: 170,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: AppColors.mutedInk,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4EE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attachment_rounded,
                              size: 16,
                              color: AppColors.forest,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Attachment',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (comment.body.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      comment.body,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatConversationDay(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);

  if (date == today) {
    return 'Today';
  }

  if (date == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }

  const monthLabels = [
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

  return '${monthLabels[value.month - 1]} ${value.day}';
}

String _formatConversationTime(DateTime value) {
  final now = DateTime.now();
  final isSameDay =
      now.year == value.year &&
      now.month == value.month &&
      now.day == value.day;

  if (!isSameDay) {
    return _formatConversationDay(value);
  }

  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $meridiem';
}
