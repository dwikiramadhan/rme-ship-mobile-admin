import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../offline/http_cache.dart';
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

  /// Callback triggered when a 401 Unauthorized response is received on a non-login endpoint.
  static void Function()? onUnauthorized;

  static Dio get instance {
    if (_instance != null) return _instance!;

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        // Generous limits: the cloud backend is reached over ship internet
        // (satellite / cellular), and uploads carry photos and lab files.
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
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

          if (kDebugMode) {
            debugPrint('🌐 [API REQ] ${options.method.toUpperCase()} ${options.uri}');
            // Never log credentials, even in debug builds.
            if (options.data != null && !_isAuthPath(options.path)) {
              debugPrint('   📦 Body: ${options.data}');
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            final method = response.requestOptions.method.toUpperCase();
            debugPrint('✅ [API RES] ${response.statusCode} $method ${response.requestOptions.uri}');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          final fullUrl = e.requestOptions.uri.toString();
          if (kDebugMode) {
            final method = e.requestOptions.method.toUpperCase();
            final status = e.response?.statusCode ?? 'ERROR';
            debugPrint('❌ [API ERR] $status $method $fullUrl -> ${e.message}');
            if (e.response?.data != null) {
              debugPrint('   ⚠️ Error Body: ${e.response?.data}');
            }
          }

          final statusCode = e.response?.statusCode;
          final isLoginEndpoint = e.requestOptions.path.contains(ApiConfig.loginPath);
          if (statusCode == 401 && !isLoginEndpoint) {
            if (kDebugMode) {
              debugPrint('🔒 [API ERR] 401 Unauthorized detected on $fullUrl -> redirecting to login');
            }
            await _storage.clear();
            onUnauthorized?.call();
          }

          return handler.next(e);
        },
      ),
    );

    dio.interceptors.add(RetryInterceptor(dio));
    // After the retries: only a GET that still fails falls back to the cache.
    dio.interceptors.add(OfflineCacheInterceptor());

    return _instance = dio;
  }

  /// True when [error] means the request never reached the server, so it can
  /// be queued and replayed later without risk of applying it twice. Send /
  /// receive timeouts are excluded: the server may already have handled them.
  static bool isOffline(DioException error) => switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout =>
          true,
        _ => false,
      };

  static bool _isAuthPath(String path) =>
      path.contains(ApiConfig.loginPath) || path.contains(ApiConfig.changePasswordPath);

  /// Maps Dio's transport-level failures into an [ApiException] the UI can
  /// show directly. Callers still need to interpret their own response body
  /// for domain-specific error messages (e.g. "invalid credentials").
  static ApiException mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final url = error.requestOptions.uri.toString();

    return switch (error.type) {
      DioExceptionType.connectionTimeout => ApiException(
          'Koneksi timeout ke $url. Periksa jaringan Anda.',
          isOffline: true,
        ),
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        ApiException('Koneksi timeout ke $url. Periksa jaringan Anda.'),
      DioExceptionType.connectionError => ApiException(
          'Tidak dapat terhubung ke server ($url).',
          statusCode: statusCode,
          isOffline: true,
        ),
      DioExceptionType.badResponse => () {
          final serverMessage = switch (error.response?.data) {
            {'message': final String msg} => msg,
            {'error': final String err} => err,
            _ => null,
          };
          if (statusCode == 401) {
            return ApiException(serverMessage ?? 'Email atau password salah.', statusCode: statusCode);
          }
          return ApiException(
            serverMessage ?? 'Terjadi kesalahan pada server (${statusCode ?? '-'}).',
            statusCode: statusCode,
          );
        }(),
      DioExceptionType.cancel => const ApiException('Permintaan dibatalkan.'),
      _ => const ApiException('Terjadi kesalahan yang tidak terduga.'),
    };
  }
}

/// Retries idempotent GET requests that failed for transient reasons
/// (connection drop, 502/503/504) with exponential backoff. 4xx responses,
/// timeouts, cancellations and non-GET requests are never retried.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.baseDelay = const Duration(milliseconds: 400)});

  final Dio _dio;
  final Duration baseDelay;

  static const _maxRetries = 2;
  static const _attemptKey = 'retry_attempt';
  static const _retryableStatuses = {502, 503, 504};

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= _maxRetries || !_isRetryable(err)) {
      return handler.next(err);
    }

    await Future<void>.delayed(baseDelay * (1 << attempt));
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    final options = err.requestOptions;
    if (options.method.toUpperCase() != 'GET') return false;
    if (options.cancelToken?.isCancelled ?? false) return false;
    return switch (err.type) {
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse =>
        _retryableStatuses.contains(err.response?.statusCode),
      _ => false,
    };
  }
}
