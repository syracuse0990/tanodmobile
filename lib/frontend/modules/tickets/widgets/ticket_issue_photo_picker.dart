import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';

class TicketIssuePhotoPicker extends StatelessWidget {
  const TicketIssuePhotoPicker({
    super.key,
    required this.label,
    required this.subtitle,
    required this.maxPhotos,
    required this.photos,
    required this.isProcessing,
    required this.processingLabel,
    required this.onPickGallery,
    required this.onCapture,
    required this.onRemove,
    this.errorText,
    this.onPickVideo,
    this.onCaptureVideo,
  });

  final String label;
  final String subtitle;
  final int maxPhotos;
  final List<TicketIssuePhoto> photos;
  final bool isProcessing;
  final String processingLabel;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;
  final ValueChanged<int> onRemove;
  final String? errorText;
  final VoidCallback? onPickVideo;
  final VoidCallback? onCaptureVideo;

  @override
  Widget build(BuildContext context) {
    final atMax = photos.length >= maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: errorText != null
                      ? AppColors.danger.withValues(alpha: 0.6)
                      : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedInk.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forest.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${photos.length}/$maxPhotos',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (photos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7F4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 34,
                            color: AppColors.forest.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Add at least one issue photo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'TanodTractor stamps each upload with a verified badge, GPS coordinates, and timestamp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.mutedInk.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumnWidth = (constraints.maxWidth - 12) / 2;
                        final cardWidth = photos.length == 1
                            ? constraints.maxWidth
                            : twoColumnWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var index = 0; index < photos.length; index++)
                              _TicketIssuePhotoCard(
                                width: cardWidth,
                                photo: photos[index],
                                index: index,
                                total: photos.length,
                                onRemove: () => onRemove(index),
                              ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing || atMax
                              ? null
                              : onPickGallery,
                          icon: const Icon(Icons.photo_library_rounded, size: 20),
                          label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing || atMax ? null : onCapture,
                          icon: const Icon(Icons.camera_alt_rounded, size: 20),
                          label: const Text('Camera', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.forest
                                .withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (onPickVideo != null || onCaptureVideo != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isProcessing || atMax
                                ? null
                                : () => _showVideoSourceSheet(
                                    context,
                                    onPickVideo: onPickVideo,
                                    onCaptureVideo: onCaptureVideo,
                                  ),
                            icon: const Icon(Icons.videocam_rounded, size: 20),
                            label: const Text('Video', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFFC4B5FD)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isProcessing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102119),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF8DD6A5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              processingLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}

class _TicketIssuePhotoCard extends StatelessWidget {
  const _TicketIssuePhotoCard({
    required this.width,
    required this.photo,
    required this.index,
    required this.total,
    required this.onRemove,
  });

  final double width;
  final TicketIssuePhoto photo;
  final int index;
  final int total;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = photo.isVideo;

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => _showFilePreview(
                context,
                photo.file,
                title: isVideo ? 'Verified video ${index + 1}' : 'Verified photo ${index + 1}',
                isVideo: isVideo,
              ),
              child: AspectRatio(
                aspectRatio: 0.95,
                child: isVideo
                    ? Container(
                        color: const Color(0xFF1A1A2E),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 48,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      )
                    : Image.file(photo.file, fit: BoxFit.cover),
              ),
            ),
            if (isVideo)
              const Positioned(
                top: 10,
                left: 10,
                child: _VideoBadge(),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isVideo
                                ? const Color(0xFF7C3AED)
                                : AppColors.forest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isVideo
                                ? 'GPS Verified Video'
                                : 'Verified by TanodTractor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      photo.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        color: Color(0xFFE2EAE5),
                      ),
                    ),
                    if (photo.addressLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        photo.addressLabel!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.28,
                          color: Color(0xFFD0DED6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      isVideo ? 'Video ${index + 1} of $total' : 'Photo ${index + 1} of $total',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isVideo
                            ? const Color(0xFFC4B5FD)
                            : const Color(0xFF8DD6A5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
          SizedBox(width: 2),
          Text(
            'VIDEO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

void _showVideoSourceSheet(
  BuildContext context, {
  required VoidCallback? onPickVideo,
  required VoidCallback? onCaptureVideo,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Video',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            if (onPickVideo != null)
              ListTile(
                leading: const Icon(
                  Icons.video_library_rounded,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing video (max 5 min)'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPickVideo();
                },
              ),
            if (onCaptureVideo != null)
              ListTile(
                leading: const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFF7C3AED),
                ),
                title: const Text('Record Video'),
                subtitle: const Text('Capture a new video (max 5 min)'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onCaptureVideo();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

void _showFilePreview(
  BuildContext context,
  File file, {
  required String title,
  bool isVideo = false,
}) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isVideo)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 64,
                        color: Color(0xFF7C3AED),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Video Preview',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      height: 220,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
