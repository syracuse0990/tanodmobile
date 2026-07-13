import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TractorOcrService {
  /// Extract text from an image file using ML Kit text recognition.
  static Future<String> extractText(File imageFile) async {
    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      textRecognizer.close();
    }
  }

  /// Extract the serial number from raw OCR text.
  /// Looks for patterns like:
  ///   - "PIN NUMBER" or "PIN" followed by a code
  ///   - Barcode sticker: KMC5825ACSF PV0326
  ///   - Any long alphanumeric string (8+ chars, mix of letters and digits)
  static String? extractSerialNumber(String rawText) {
    final lines = rawText.split('\n');

    // 1. First, look for lines containing "PIN" or "SERIAL"
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (upper.contains('PIN') || upper.contains('SERIAL') || upper.contains('ID NO')) {
        final code = RegExp(r'[A-Z0-9]{8,}').firstMatch(line.replaceAll('*', ''));
        if (code != null) {
          return code.group(0);
        }
      }
    }

    // 2. KMC barcode format: KMC5825ACSF PV0326
    final kmcMatch = RegExp(r'KMC\d{4}[A-Z]{3,5}\s+[A-Z0-9]+', caseSensitive: false)
        .firstMatch(rawText);
    if (kmcMatch != null) {
      return kmcMatch.group(0)?.trim();
    }

    // 3. KMC compact format: KMC + digits + letters + digits (no spaces)
    final kmcCompact = RegExp(r'KMC\d{4}[A-Z]{4,}\d{4}', caseSensitive: false)
        .firstMatch(rawText);
    if (kmcCompact != null) {
      return kmcCompact.group(0);
    }

    // 4. Look for long alphanumeric strings (serial-like: letters AND digits)
    for (final line in lines) {
      final cleaned = line.replaceAll(RegExp(r'[\s*#\-]'), '');
      final match = RegExp(r'[A-Z]{2,}\d{2,}[A-Z0-9]{2,}\d{2,}').firstMatch(cleaned);
      if (match != null) {
        final code = match.group(0);
        if (code != null && code.length >= 10) return code;
      }
    }

    return null;
  }

  /// Extract engine number: PTS + digits, or letters + digits
  static String? extractEngineNumber(String rawText) {
    final ptsMatch = RegExp(r'PTS\s*\d{3,}', caseSensitive: false).firstMatch(rawText);
    if (ptsMatch != null) return ptsMatch.group(0)?.replaceAll(RegExp(r'\s+'), '');

    final lines = rawText.split('\n');
    for (final line in lines) {
      final cleaned = line.replaceAll(RegExp(r'[\s*#]'), '');
      final match = RegExp(r'[A-Z]{3,6}\d{4,8}').firstMatch(cleaned);
      if (match != null) {
        final code = match.group(0);
        if (code != null && code.length >= 7) return code;
      }
    }
    return null;
  }

  /// Extract front loader SN: WR-SERIES 1444PH or R-SERIES 098PH
  static String? extractFrontLoaderSn(String rawText) {
    // WR-SERIES 1444PH or R-SERIES 098PH
    final match = RegExp(r'[A-Z]+[\-\s]*SERIES\s*\d{3,}[A-Z0-9]{1,4}', caseSensitive: false)
        .firstMatch(rawText);
    if (match != null) {
      return match.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return null;
  }

  /// Extract rotavator SN: LSGW1750-RMP-24001352
  static String? extractRotaryTillerSn(String rawText) {
    // Exact: LSGW1750-RMP-24001352 or LSGW1750 RMP 24001352
    final match = RegExp(r'LSGW\s*\d{3,4}[\-\s]*RMP[\-\s]*\d{7,8}', caseSensitive: false)
        .firstMatch(rawText);
    if (match != null) {
      return match.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // Fallback: just LSGW + digits
    final fallback = RegExp(r'LSGW\s*\d{3,}', caseSensitive: false).firstMatch(rawText);
    if (fallback != null) {
      return fallback.group(0)?.replaceAll(RegExp(r'\s+'), '');
    }
    return null;
  }

  /// Extract disk plow SN: WDP-RMP25121328 or WDP40 RMP 2312030
  static String? extractDiscPlowSn(String rawText) {
    // Exact: WDP-RMP25121328 (dash, no spaces)
    final match = RegExp(r'WDP[\-\s]*RMP[\-\s]*\d{7,8}', caseSensitive: false)
        .firstMatch(rawText);
    if (match != null) {
      return match.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // Fallback: just WDP + digits
    final fallback = RegExp(r'WDP\s*\d{2,3}', caseSensitive: false).firstMatch(rawText);
    if (fallback != null) {
      return fallback.group(0)?.replaceAll(RegExp(r'\s+'), '');
    }
    return null;
  }

  /// Main entry point: extract the right SN based on field key.
  static Future<String?> recognizeAndExtract(File imageFile, String fieldKey) async {
    final rawText = await extractText(imageFile);
    if (rawText.isEmpty) return null;

    debugPrint('OCR raw text: $rawText');

    switch (fieldKey) {
      case 'id_no':
        return extractSerialNumber(rawText);
      case 'engine_no':
        return extractEngineNumber(rawText);
      case 'front_loader_sn':
        return extractFrontLoaderSn(rawText);
      case 'rotary_tiller_sn':
        return extractRotaryTillerSn(rawText);
      case 'disc_plow_sn':
        return extractDiscPlowSn(rawText);
      default:
        return null;
    }
  }
}
