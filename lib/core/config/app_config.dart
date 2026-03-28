class AppConfig {
  const AppConfig._();

  static const String appName = 'Tanod Mobile';
  static const String apiBaseUrl = String.fromEnvironment(
    'TANOD_API_BASE_URL',
    defaultValue: 'http://192.168.1.24:8000/api/v1',
  );
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
}
