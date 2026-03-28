import 'package:dio/dio.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._hiveService);

  final HiveService _hiveService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = _hiveService.getSession();

    if (session != null && session.token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${session.token}';
    }

    handler.next(options);
  }
}
