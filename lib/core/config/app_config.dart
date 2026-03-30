import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static const String appName = 'Tanod Mobile';
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1';

  // WebSocket
  static String get websocketHost => dotenv.env['WEBSOCKET_HOST'] ?? 'localhost';
  static String get websocketKey => dotenv.env['WEBSOCKET_KEY'] ?? '';
  static int get websocketPort => int.tryParse(dotenv.env['WEBSOCKET_PORT'] ?? '443') ?? 443;
  static bool get websocketUseTls => (dotenv.env['WEBSOCKET_USE_TLS'] ?? 'true') == 'true';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
}
