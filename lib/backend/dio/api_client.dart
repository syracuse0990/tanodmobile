import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
    );
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.put<dynamic>(path, data: data);
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.delete<dynamic>(path, data: data);
    return _mapResponse(response);
  }

  /// Sends a multipart/form-data POST request (for file uploads).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData formData,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _mapResponse(response);
  }

  Map<String, dynamic> _mapResponse(Response<dynamic> response) {
    final body = response.data;

    if (body is Map<String, dynamic>) {
      return body;
    }

    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }

    return {'data': body};
  }
}
