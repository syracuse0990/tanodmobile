import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';

class TicketIssuePhotoService {
  TicketIssuePhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const int maxPhotos = 2;
  static const double _maxSinglePhotoDimension = 1100;

  final ImagePicker _picker;
  final DateFormat _timestampFormat = DateFormat('MMM d, yyyy | h:mm a');

  Future<List<TicketIssuePhoto>> pickFromGallery({int? remainingSlots}) async {
    if (remainingSlots != null && remainingSlots <= 0) {
      return const [];
    }

    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) {
        return const [];
      }

      final limitedFiles = remainingSlots == null
          ? pickedFiles
          : pickedFiles.take(remainingSlots).toList(growable: false);
      return _buildVerifiedPhotos(limitedFiles);
    } on MissingPluginException {
      throw const TicketIssuePhotoException(
        'Restart the app once so the gallery verification tools can finish loading.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.pickFromGallery platform error: '
        '$error\n$stackTrace',
      );

      throw TicketIssuePhotoException(_pickerPlatformMessage(error));
    } on TicketIssuePhotoException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.pickFromGallery error: '
        '$error\n$stackTrace',
      );

      throw const TicketIssuePhotoException(
        'Unable to open the photo gallery right now. Please try again.',
      );
    }
  }

  Future<TicketIssuePhoto?> captureWithCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return null;
      }

      final verifiedPhotos = await _buildVerifiedPhotos([pickedFile]);
      if (verifiedPhotos.isEmpty) {
        return null;
      }

      return verifiedPhotos.first;
    } on MissingPluginException {
      throw const TicketIssuePhotoException(
        'Restart the app once so the camera verification tools can finish loading.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.captureWithCamera platform error: '
        '$error\n$stackTrace',
      );

      throw TicketIssuePhotoException(_pickerPlatformMessage(error));
    } on TicketIssuePhotoException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.captureWithCamera error: '
        '$error\n$stackTrace',
      );

      throw const TicketIssuePhotoException(
        'Unable to open the camera right now. Please try again.',
      );
    }
  }

  /// Pick a single video from the gallery.
  Future<TicketIssuePhoto?> pickVideoFromGallery() async {
    try {
      final pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null) {
        return null;
      }

      final snapshot = await _captureSnapshot();
      return TicketIssuePhoto(
        file: File(pickedFile.path),
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        verifiedAt: snapshot.verifiedAt,
        address: snapshot.address,
        isVideo: true,
      );
    } on MissingPluginException {
      throw const TicketIssuePhotoException(
        'Restart the app once so the video tools can finish loading.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.pickVideoFromGallery platform error: '
        '$error\n$stackTrace',
      );

      throw TicketIssuePhotoException(_pickerPlatformMessage(error));
    } on TicketIssuePhotoException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.pickVideoFromGallery error: '
        '$error\n$stackTrace',
      );

      throw const TicketIssuePhotoException(
        'Unable to pick a video right now. Please try again.',
      );
    }
  }

  /// Capture a video using the camera.
  Future<TicketIssuePhoto?> captureVideo() async {
    try {
      final pickedFile = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null) {
        return null;
      }

      final snapshot = await _captureSnapshot();
      return TicketIssuePhoto(
        file: File(pickedFile.path),
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        verifiedAt: snapshot.verifiedAt,
        address: snapshot.address,
        isVideo: true,
      );
    } on MissingPluginException {
      throw const TicketIssuePhotoException(
        'Restart the app once so the video tools can finish loading.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.captureVideo platform error: '
        '$error\n$stackTrace',
      );

      throw TicketIssuePhotoException(_pickerPlatformMessage(error));
    } on TicketIssuePhotoException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService.captureVideo error: '
        '$error\n$stackTrace',
      );

      throw const TicketIssuePhotoException(
        'Unable to capture video right now. Please try again.',
      );
    }
  }

  Future<File?> buildUploadPhoto(List<TicketIssuePhoto> photos) async {
    if (photos.isEmpty) {
      return null;
    }

    if (photos.length == 1) {
      return photos.first.file;
    }

    return _mergeIntoProofSheet(photos);
  }

  Future<File> _mergeIntoProofSheet(List<TicketIssuePhoto> photos) async {
    const double maxSheetWidth = 1080;
    const double spacing = 4;

    final images = <ui.Image>[];
    for (final photo in photos) {
      final bytes = await photo.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      images.add(frame.image);
    }

    final sheetWidth = maxSheetWidth;
    final itemHeight = sheetWidth / images.length;
    final sheetHeight = (itemHeight * images.length) + (spacing * (images.length - 1));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sheetWidth, sheetHeight),
    );

    canvas.drawColor(const Color(0xFF1A1A1A), BlendMode.srcOver);

    var yOffset = 0.0;
    for (final image in images) {
      final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dstRect = Rect.fromLTWH(0, yOffset, sheetWidth, itemHeight);
      canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
      yOffset += itemHeight + spacing;
    }

    final renderedImage = await recorder.endRecording().toImage(
      sheetWidth.round(),
      sheetHeight.round(),
    );
    final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw const TicketIssuePhotoException('Unable to prepare the verified proof sheet for upload.');
    }

    return _writeTempFile(
      bytes: byteData.buffer.asUint8List(),
      prefix: 'ticket-proof-sheet',
    );
  }

  Future<List<TicketIssuePhoto>> _buildVerifiedPhotos(
    List<XFile> sourceFiles,
  ) async {
    if (sourceFiles.isEmpty) {
      return const [];
    }

    final snapshot = await _captureSnapshot();
    final verifiedPhotos = <TicketIssuePhoto>[];

    for (final sourceFile in sourceFiles) {
      final verifiedFile = await _renderVerifiedPhoto(
        sourceFile,
        snapshot: snapshot,
      );

      verifiedPhotos.add(
        TicketIssuePhoto(
          file: verifiedFile,
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
          verifiedAt: snapshot.verifiedAt,
          address: snapshot.address,
        ),
      );
    }

    return verifiedPhotos;
  }

  Future<_TicketIssuePhotoSnapshot> _captureSnapshot() async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        throw const TicketIssuePhotoException(
          'Turn on location services to verify ticket photos.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const TicketIssuePhotoException(
          'Location permission is required to stamp verified ticket photos.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return _buildSnapshot(position.latitude, position.longitude);
    } on MissingPluginException {
      throw const TicketIssuePhotoException(
        'Restart the app once so location verification can finish loading.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService._captureSnapshot platform error: '
        '$error\n$stackTrace',
      );

      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('permission') || message.contains('permission')) {
        throw const TicketIssuePhotoException(
          'Allow location access to verify ticket photos.',
        );
      }

      throw const TicketIssuePhotoException(
        'Unable to verify your location right now. Move to an open area and try again.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService._captureSnapshot current location error: '
        '$error\n$stackTrace',
      );

      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return _buildSnapshot(lastKnown.latitude, lastKnown.longitude);
        }
      } catch (fallbackError, fallbackStackTrace) {
        debugPrint(
          'TicketIssuePhotoService._captureSnapshot last known location '
          'error: $fallbackError\n$fallbackStackTrace',
        );
      }

      throw const TicketIssuePhotoException(
        'Unable to verify your location right now. Move to an open area and try again.',
      );
    }
  }

  Future<_TicketIssuePhotoSnapshot> _buildSnapshot(
    double latitude,
    double longitude,
  ) async {
    final verifiedAt = DateTime.now();
    final address = await _resolveAddress(latitude, longitude);

    return _TicketIssuePhotoSnapshot(
      latitude: latitude,
      longitude: longitude,
      verifiedAt: verifiedAt,
      address: address,
    );
  }

  Future<String?> _resolveAddress(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final parts = <String>[];

      void addPart(String? value) {
        final trimmed = value?.trim();
        if (trimmed == null || trimmed.isEmpty) {
          return;
        }

        final exists = parts.any(
          (part) => part.toLowerCase() == trimmed.toLowerCase(),
        );
        if (!exists) {
          parts.add(trimmed);
        }
      }

      final streetParts = [placemark.subThoroughfare, placemark.thoroughfare]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

      addPart(placemark.name);
      if (streetParts.isNotEmpty) {
        addPart(streetParts.join(' '));
      }
      addPart(placemark.subLocality);
      addPart(placemark.locality);
      addPart(placemark.subAdministrativeArea);
      addPart(placemark.administrativeArea);
      addPart(placemark.postalCode);
      addPart(placemark.country);

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(', ');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService._resolveAddress missing plugin: '
        '$error\n$stackTrace',
      );
      return null;
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService._resolveAddress platform error: '
        '$error\n$stackTrace',
      );
      return null;
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService._resolveAddress error: '
        '$error\n$stackTrace',
      );
      return null;
    }
  }

  String _pickerPlatformMessage(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();

    if (code.contains('permission') || message.contains('permission')) {
      return 'Allow camera and photo access to add a verified issue photo.';
    }

    if (code.contains('camera') || message.contains('camera')) {
      return 'Unable to open the camera right now. Please close other camera apps and try again.';
    }

    if (code.contains('gallery') || message.contains('gallery')) {
      return 'Unable to open the photo gallery right now. Please try again.';
    }

    return 'Unable to access your photo tools right now. Please try again.';
  }

  Future<File> _renderVerifiedPhoto(
    XFile sourceFile, {
    required _TicketIssuePhotoSnapshot snapshot,
  }) async {
    try {
      final image = await _decodeImage(await sourceFile.readAsBytes());
      final sourceWidth = image.width.toDouble();
      final sourceHeight = image.height.toDouble();
      final scale = math.min(
        1,
        _maxSinglePhotoDimension / math.max(sourceWidth, sourceHeight),
      );
      final outputWidth = sourceWidth * scale;
      final outputHeight = sourceHeight * scale;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, outputWidth, outputHeight),
      );

      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, outputWidth, outputHeight),
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );

      _drawVerifiedOverlay(canvas, Size(outputWidth, outputHeight), snapshot);

      final renderedImage = await recorder.endRecording().toImage(
        outputWidth.round(),
        outputHeight.round(),
      );
      final byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw const TicketIssuePhotoException(
          'Unable to prepare the verified photo for upload.',
        );
      }

      return _writeTempFile(
        bytes: byteData.buffer.asUint8List(),
        prefix: 'ticket-verified-photo',
      );
    } on TicketIssuePhotoException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'TicketIssuePhotoService._renderVerifiedPhoto error: '
        '$error\n$stackTrace',
      );

      throw const TicketIssuePhotoException(
        'Unable to prepare this photo for secure verification. Try taking a new photo or choose a JPG or PNG image.',
      );
    }
  }

  void _drawVerifiedOverlay(
    Canvas canvas,
    Size size,
    _TicketIssuePhotoSnapshot snapshot,
  ) {
    final hasAddress =
        snapshot.address != null && snapshot.address!.trim().isNotEmpty;
    final margin = math.max(size.width * 0.045, 18.0);
    final badgeWidth = math.min(size.width - (margin * 2), 430.0);
    final badgeHeight = math.max(size.height * 0.08, 52.0);
    final infoWidth = size.width - (margin * 2);
    final infoHeight = math.max(
      size.height * (hasAddress ? 0.19 : 0.13),
      hasAddress ? 136.0 : 96.0,
    );
    final infoTop = size.height - margin - infoHeight;
    final badgeTop = math.max(margin, infoTop - badgeHeight - 12);
    final badgeRect = Rect.fromLTWH(margin, badgeTop, badgeWidth, badgeHeight);
    final infoRect = Rect.fromLTWH(margin, infoTop, infoWidth, infoHeight);

    _drawGlassCard(
      canvas,
      badgeRect,
      gradient: const [Color(0xF2162A21), Color(0xD9162A21)],
    );
    _drawGlassCard(
      canvas,
      infoRect,
      gradient: const [Color(0xF20D1511), Color(0xD90D1511)],
    );

    final badgePadding = math.max(badgeHeight * 0.26, 12.0);
    final badgeCenter = Offset(
      badgeRect.left + badgePadding + 10,
      badgeRect.center.dy,
    );
    _drawCheckBadge(canvas, badgeCenter, math.max(badgeHeight * 0.22, 9.0));

    final verifiedPainter = TextPainter(
      text: TextSpan(
        children: const [
          TextSpan(
            text: 'Verified by ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: 'TanodTractor',
            style: TextStyle(
              color: Color(0xFF8DD6A5),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: badgeRect.width - (badgePadding * 2) - 34);

    verifiedPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx + 18,
        badgeRect.top + (badgeRect.height - verifiedPainter.height) / 2,
      ),
    );

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'GPS VERIFIED',
        style: TextStyle(
          color: Color(0xFF8DD6A5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: infoRect.width - 28);

    final coordinatesPainter = TextPainter(
      text: TextSpan(
        text:
            'Lat ${snapshot.latitude.toStringAsFixed(6)}   Lng ${snapshot.longitude.toStringAsFixed(6)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: infoRect.width - 28);

    final timePainter = TextPainter(
      text: TextSpan(
        text: _timestampFormat.format(snapshot.verifiedAt),
        style: const TextStyle(
          color: Color(0xFFD6E3DB),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: infoRect.width - 28);

    final addressPainter = hasAddress
        ? (TextPainter(
            text: TextSpan(
              text: snapshot.address!,
              style: const TextStyle(
                color: Color(0xFFE2EAE5),
                fontSize: 11,
                height: 1.28,
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
            maxLines: 3,
            ellipsis: '...',
          )..layout(maxWidth: infoRect.width - 28))
        : null;

    final textLeft = infoRect.left + 14;
    final textTop = infoRect.top + 12;
    labelPainter.paint(canvas, Offset(textLeft, textTop));
    coordinatesPainter.paint(canvas, Offset(textLeft, textTop + 20));
    if (addressPainter != null) {
      addressPainter.paint(canvas, Offset(textLeft, textTop + 44));
    }
    timePainter.paint(
      canvas,
      Offset(textLeft, infoRect.bottom - timePainter.height - 12),
    );
  }

  void _drawGlassCard(
    Canvas canvas,
    Rect rect, {
    required List<Color> gradient,
  }) {
    final borderRadius = Radius.circular(math.min(rect.height * 0.34, 22));
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final cardPaint = Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, gradient);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final card = RRect.fromRectAndRadius(rect, borderRadius);

    canvas.drawRRect(card.shift(const Offset(0, 6)), shadowPaint);
    canvas.drawRRect(card, cardPaint);
    canvas.drawRRect(card, borderPaint);
  }

  void _drawCheckBadge(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = AppColors.forest);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.45;

    final checkPath = Path()
      ..moveTo(center.dx - (radius * 0.55), center.dy)
      ..lineTo(center.dx - (radius * 0.15), center.dy + (radius * 0.45))
      ..lineTo(center.dx + (radius * 0.65), center.dy - (radius * 0.45));

    canvas.drawPath(checkPath, checkPaint);
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<File> _writeTempFile({
    required Uint8List bytes,
    required String prefix,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$prefix-${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class _TicketIssuePhotoSnapshot {
  const _TicketIssuePhotoSnapshot({
    required this.latitude,
    required this.longitude,
    required this.verifiedAt,
    this.address,
  });

  final double latitude;
  final double longitude;
  final DateTime verifiedAt;
  final String? address;
}
