import 'package:tanodmobile/core/config/app_config.dart';

class UrlHelper {
  UrlHelper._();

  /// Server base URL without the /api/vN suffix.
  static String get serverBaseUrl =>
      AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v\d+$'), '');

  /// Guarantee a correct absolute storage URL from any server response.
  ///
  /// Handles: relative paths, absolute-but-wrong-prefix URLs, and
  /// already-correct absolute URLs.
  static String? fixStorageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;

    // Already correct
    if (rawUrl.startsWith('http') && !rawUrl.contains('/api/v')) {
      return rawUrl;
    }

    // Extract the storage path portion
    final path = rawUrl.contains('/storage/')
        ? rawUrl.split('/storage/').last
        : rawUrl;

    return '$serverBaseUrl/storage/$path';
  }
}
