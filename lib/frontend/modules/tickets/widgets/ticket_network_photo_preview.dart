import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class TicketNetworkPhotoPreview extends StatefulWidget {
  const TicketNetworkPhotoPreview({
    super.key,
    required this.imageUrl,
    required this.title,
    this.height = 220,
  });

  final String imageUrl;
  final String title;
  final double height;

  @override
  State<TicketNetworkPhotoPreview> createState() =>
      _TicketNetworkPhotoPreviewState();
}

class _TicketNetworkPhotoPreviewState extends State<TicketNetworkPhotoPreview> {
  late Future<_TicketPhotoPreviewData> _previewFuture;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _previewFuture = _TicketPhotoPreviewData.load(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant TicketNetworkPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _currentPage = 0;
      _previewFuture = _TicketPhotoPreviewData.load(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TicketPhotoPreviewData>(
      future: _previewFuture,
      builder: (context, snapshot) {
        final previewData = snapshot.data;
        final slides = previewData?.slides;
        final hasCarousel = slides != null && slides.length > 1;

        return GestureDetector(
          onTap: () {
            if (previewData == null) {
              return;
            }

            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.88),
              builder: (_) => _TicketPhotoPreviewDialog(
                previewData: previewData,
                title: widget.title,
                initialPage: _currentPage,
              ),
            );
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: widget.height,
                  color: const Color(0xFFE9EFEB),
                  child: hasCarousel
                      ? PageView.builder(
                          itemCount: slides.length,
                          onPageChanged: (page) {
                            if (mounted) {
                              setState(() => _currentPage = page);
                            }
                          },
                          itemBuilder: (context, index) {
                            return _PreviewImage(
                              image: Image.memory(
                                slides[index],
                                width: double.infinity,
                                height: widget.height,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) =>
                                    const _BrokenTicketPhoto(),
                              ),
                            );
                          },
                        )
                      : _PreviewImage(
                          image: previewData != null
                              ? Image.memory(
                                  previewData.slides.first,
                                  width: double.infinity,
                                  height: widget.height,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) =>
                                      const _BrokenTicketPhoto(),
                                )
                              : Image.network(
                                  widget.imageUrl,
                                  width: double.infinity,
                                  height: widget.height,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const _BrokenTicketPhoto(),
                                ),
                        ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasCarousel
                            ? Icons.swipe_left_alt_rounded
                            : Icons.zoom_out_map_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasCarousel ? 'Swipe or tap to view' : 'Tap to preview',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasCarousel)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${slides.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.image});

  final Widget image;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: image,
    );
  }
}

class _BrokenTicketPhoto extends StatelessWidget {
  const _BrokenTicketPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: AppColors.mutedInk),
      ),
    );
  }
}

class _TicketPhotoPreviewDialog extends StatefulWidget {
  const _TicketPhotoPreviewDialog({
    required this.previewData,
    required this.title,
    required this.initialPage,
  });

  final _TicketPhotoPreviewData previewData;
  final String title;
  final int initialPage;

  @override
  State<_TicketPhotoPreviewDialog> createState() =>
      _TicketPhotoPreviewDialogState();
}

class _TicketPhotoPreviewDialogState extends State<_TicketPhotoPreviewDialog> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.previewData.slides;
    final hasCarousel = slides.length > 1;

    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasCarousel)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forest.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${slides.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasCarousel)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Swipe left or right to view the next photo. Pinch to zoom if needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            Expanded(
              child: hasCarousel
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: slides.length,
                      onPageChanged: (page) {
                        if (mounted) {
                          setState(() => _currentPage = page);
                        }
                      },
                      itemBuilder: (context, index) {
                        return _FullscreenSlide(bytes: slides[index]);
                      },
                    )
                  : _FullscreenSlide(bytes: slides.first),
            ),
            if (hasCarousel)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(slides.length, (index) {
                    final active = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.forest
                            : Colors.white.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenSlide extends StatelessWidget {
  const _FullscreenSlide({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const _BrokenTicketPhoto(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketPhotoPreviewData {
  const _TicketPhotoPreviewData({required this.slides});

  static const Color _proofSheetBackground = Color(0xFFF2F6F2);
  static const double _proofSheetWidth = 920;
  static const double _proofSheetPadding = 30;
  static const double _proofSheetHeaderAndTopGap = 126;

  final List<Uint8List> slides;

  static Future<_TicketPhotoPreviewData> load(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final assetBundle = NetworkAssetBundle(uri);
      final byteData = await assetBundle.load(uri.toString());
      final originalBytes = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      try {
        final rawBytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (rawBytes == null || !_looksLikeProofSheet(image, rawBytes)) {
          return _TicketPhotoPreviewData(slides: [originalBytes]);
        }

        final bands = _detectProofSheetBands(image, rawBytes);
        if (bands.length != 2) {
          return _TicketPhotoPreviewData(slides: [originalBytes]);
        }

        final slides = <Uint8List>[];
        for (final band in bands) {
          slides.add(await _cropBand(image, band));
        }

        return _TicketPhotoPreviewData(slides: slides);
      } finally {
        image.dispose();
        codec.dispose();
      }
    } catch (_) {
      final uri = Uri.parse(imageUrl);
      final assetBundle = NetworkAssetBundle(uri);
      final byteData = await assetBundle.load(uri.toString());
      return _TicketPhotoPreviewData(slides: [byteData.buffer.asUint8List()]);
    }
  }

  static bool _looksLikeProofSheet(ui.Image image, ByteData rawBytes) {
    if (image.height < image.width * 1.45) {
      return false;
    }

    final pixels = rawBytes.buffer.asUint8List();
    final scale = image.width / _proofSheetWidth;
    final probeInset = math.max((10 * scale).round(), 4);
    final samplePoints = <Offset>[
      Offset(probeInset.toDouble(), probeInset.toDouble()),
      Offset((image.width / 2).roundToDouble(), probeInset.toDouble()),
      Offset(
        (image.width - probeInset - 1).roundToDouble(),
        probeInset.toDouble(),
      ),
      Offset(probeInset.toDouble(), (image.height - probeInset - 1).toDouble()),
      Offset(
        (image.width / 2).roundToDouble(),
        (image.height - probeInset - 1).toDouble(),
      ),
      Offset(
        (image.width - probeInset - 1).roundToDouble(),
        (image.height - probeInset - 1).toDouble(),
      ),
    ];

    var nearBackgroundCount = 0;
    for (final point in samplePoints) {
      if (_isNearBackground(
        pixels,
        image.width,
        point.dx.round(),
        point.dy.round(),
      )) {
        nearBackgroundCount++;
      }
    }

    return nearBackgroundCount >= 5;
  }

  static List<_VerticalBand> _detectProofSheetBands(
    ui.Image image,
    ByteData rawBytes,
  ) {
    final pixels = rawBytes.buffer.asUint8List();
    final scale = image.width / _proofSheetWidth;
    final padding = math.max((_proofSheetPadding * scale).round(), 12);
    final searchTop = math.max((_proofSheetHeaderAndTopGap * scale).round(), 0);
    final searchBottom = math.max(image.height - padding - 1, searchTop + 1);
    final xInset = math.max((56 * scale).round(), 28);
    final startX = math.min(image.width - 2, padding + xInset);
    final endX = math.max(startX + 1, image.width - padding - xInset);
    final rowStep = math.max((2 * scale).round(), 1);
    final minBandHeight = math.max((image.width * 0.34).round(), 220);
    final maxGapHeight = math.max((24 * scale).round(), 10);
    final edgePadding = math.max((18 * scale).round(), 10);
    final bands = <_VerticalBand>[];
    int? currentStart;
    var lastContentY = searchTop;
    var currentGap = 0;

    for (var y = searchTop; y <= searchBottom; y += rowStep) {
      final ratio = _contentRatioForRow(pixels, image.width, y, startX, endX);
      final isContent = ratio >= 0.42;

      if (isContent) {
        currentStart ??= y;
        lastContentY = y;
        currentGap = 0;
        continue;
      }

      if (currentStart == null) {
        continue;
      }

      currentGap += rowStep;
      if (currentGap <= maxGapHeight) {
        continue;
      }

      final band = _VerticalBand(
        start: math.max(currentStart - edgePadding, searchTop),
        end: math.min(lastContentY + edgePadding, image.height - 1),
      );
      if (band.height >= minBandHeight) {
        bands.add(band);
      }
      currentStart = null;
      currentGap = 0;
    }

    if (currentStart != null) {
      final band = _VerticalBand(
        start: math.max(currentStart - edgePadding, searchTop),
        end: math.min(lastContentY + edgePadding, image.height - 1),
      );
      if (band.height >= minBandHeight) {
        bands.add(band);
      }
    }

    return bands.take(2).toList(growable: false);
  }

  static double _contentRatioForRow(
    Uint8List pixels,
    int width,
    int y,
    int startX,
    int endX,
  ) {
    const sampleCount = 16;
    var contentSamples = 0;

    for (var index = 0; index < sampleCount; index++) {
      final progress = sampleCount == 1 ? 0.0 : index / (sampleCount - 1);
      final x = startX + ((endX - startX) * progress).round();
      if (!_isNearBackground(pixels, width, x, y)) {
        contentSamples++;
      }
    }

    return contentSamples / sampleCount;
  }

  static bool _isNearBackground(Uint8List pixels, int width, int x, int y) {
    final index = (y * width + x) * 4;
    if (index < 0 || index + 3 >= pixels.length) {
      return false;
    }

    final r = pixels[index];
    final g = pixels[index + 1];
    final b = pixels[index + 2];
    final a = pixels[index + 3];
    if (a < 240) {
      return false;
    }

    return (r - _proofSheetBackground.r).abs() <= 24 &&
        (g - _proofSheetBackground.g).abs() <= 24 &&
        (b - _proofSheetBackground.b).abs() <= 24;
  }

  static Future<Uint8List> _cropBand(ui.Image image, _VerticalBand band) async {
    final recorder = ui.PictureRecorder();
    final cropHeight = band.height;
    final cropRect = Rect.fromLTWH(
      0,
      band.start.toDouble(),
      image.width.toDouble(),
      cropHeight.toDouble(),
    );
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image.width.toDouble(), cropHeight.toDouble()),
    );

    canvas.drawImageRect(
      image,
      cropRect,
      Rect.fromLTWH(0, 0, image.width.toDouble(), cropHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final rendered = await recorder.endRecording().toImage(
      image.width,
      cropHeight,
    );
    try {
      final byteData = await rendered.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw StateError('Unable to encode cropped preview');
      }

      return byteData.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  }
}

class _VerticalBand {
  const _VerticalBand({required this.start, required this.end});

  final int start;
  final int end;

  int get height => math.max(end - start, 1);
}
