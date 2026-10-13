import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/core/network/api_exception.dart';
import 'package:bayan_rme/features/auth/data/password_api.dart';

/// Answers every request with [statusCode] and [data], recording it.
Dio _dioAnswering(
  List<RequestOptions> requests, {
  int statusCode = 200,
  Object? data,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        final response = Response(
          requestOptions: options,
          statusCode: statusCode,
          data: data,
        );
        if (statusCode >= 400) {
          return handler.reject(
            DioException.badResponse(
              statusCode: statusCode,
              requestOptions: options,
              response: response,
            ),
          );
        }
        return handler.resolve(response);
      },
    ),
  );
  return dio;
}

void main() {
  test('changes the password the way the backend expects', () async {
    final requests = <RequestOptions>[];
    final api = PasswordApi(dio: _dioAnswering(requests));

    await api.changePassword(oldPassword: 'lama123', newPassword: 'baru456');

    expect(requests, hasLength(1));
    expect(requests.single.method, 'PUT');
    expect(requests.single.path, '/api/v1/auth/me/password');
    expect(requests.single.data, {
      'current_password': 'lama123',
      'new_password': 'baru456',
    });
  });

  test('shows the server message for a wrong current password', () async {
    final api = PasswordApi(
      dio: _dioAnswering(
        [],
        statusCode: 400,
        data: {'message': 'password saat ini salah'},
      ),
    );

    await expectLater(
      api.changePassword(oldPassword: 'salah', newPassword: 'baru456'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'password saat ini salah',
        ),
      ),
    );
  });
}
