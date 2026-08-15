import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';

/// Thin factory around [Dio] — a single client instance shared by every
/// feature's API layer, pre-configured with the base URL and sane timeouts.
class DioClient {
  DioClient._();

  static Dio? _instance;

  static Dio get instance {
    return _instance ??= Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// Maps Dio's transport-level failures into an [ApiException] the UI can
  /// show directly. Callers still need to interpret their own response body
  /// for domain-specific error messages (e.g. "invalid credentials").
  static ApiException mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Koneksi ke server timeout. Periksa jaringan Anda.');
      case DioExceptionType.connectionError:
        return const ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        String? serverMessage;
        if (data is Map && data['message'] is String) {
          serverMessage = data['message'] as String;
        } else if (data is Map && data['error'] is String) {
          serverMessage = data['error'] as String;
        }
        if (statusCode == 401) {
          return ApiException(serverMessage ?? 'Email atau password salah.', statusCode: statusCode);
        }
        return ApiException(serverMessage ?? 'Terjadi kesalahan pada server (${statusCode ?? '-'}).', statusCode: statusCode);
      case DioExceptionType.cancel:
        return const ApiException('Permintaan dibatalkan.');
      default:
        return const ApiException('Terjadi kesalahan yang tidak terduga.');
    }
  }
}
