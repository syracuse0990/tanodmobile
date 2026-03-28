import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory AppException.fromDio(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException('Connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const AppException(
          'Could not reach the server. Check your internet connection.',
        );
      case DioExceptionType.badCertificate:
        return const AppException('The server certificate is not trusted.');
      case DioExceptionType.cancel:
        return const AppException('The request was cancelled.');
      case DioExceptionType.badResponse:
        final data = exception.response?.data;
        String? message;

        if (data is Map<String, dynamic>) {
          message = data['message']?.toString();
        } else if (data is Map) {
          message = data['message']?.toString();
        }

        return AppException(
          message ?? 'The server returned an unexpected response.',
          statusCode: exception.response?.statusCode,
        );
      case DioExceptionType.unknown:
        return AppException(exception.message ?? 'Something went wrong.');
    }
  }

  @override
  String toString() => message;
}
