import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';

import '../../features/auth/data/session_storage.dart';

/// Thin factory around [Dio] — a single client instance shared by every
/// feature's API layer, pre-configured with the base URL, sane timeouts, and
/// an auth interceptor that attaches the Bearer token when available.
class DioClient {
  DioClient._();

  static Dio? _instance;
  static final SessionStorage _storage = SessionStorage();

  static Dio get instance {
    if (_instance != null) return _instance!;

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConfig.baseUrl;
          // Skip adding token for login path
          if (!options.path.contains(ApiConfig.loginPath) &&
              !options.headers.containsKey('Authorization')) {
            final session = await _storage.read();
            if (session?.token != null && session!.token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer ${session.token}';
            }
          }

          final fullUrl = options.uri.toString();
          // Log endpoint hit
          // ignore: avoid_print
          print('🌐 [API REQ] ${options.method.toUpperCase()} $fullUrl');
          if (options.data != null) {
            // ignore: avoid_print
            print('   📦 Body: ${options.data}');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          final fullUrl = response.requestOptions.uri.toString();
          final method = response.requestOptions.method.toUpperCase();
          // ignore: avoid_print
          print('✅ [API RES] ${response.statusCode} $method $fullUrl');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          final fullUrl = e.requestOptions.uri.toString();
          final method = e.requestOptions.method.toUpperCase();
          final status = e.response?.statusCode ?? 'ERROR';
          // ignore: avoid_print
          print('❌ [API ERR] $status $method $fullUrl -> ${e.message}');
          if (e.response?.data != null) {
            // ignore: avoid_print
            print('   ⚠️ Error Body: ${e.response?.data}');
          }
          return handler.next(e);
        },
      ),
    );

    return _instance = dio;
  }

  /// Maps Dio's transport-level failures into an [ApiException] the UI can
  /// show directly. Callers still need to interpret their own response body
  /// for domain-specific error messages (e.g. "invalid credentials").
  static ApiException mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final url = error.requestOptions.uri.toString();
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Koneksi timeout ke $url. Periksa jaringan Anda.');
      case DioExceptionType.connectionError:
        return ApiException('Tidak dapat terhubung ke server ($url).', statusCode: statusCode);

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
