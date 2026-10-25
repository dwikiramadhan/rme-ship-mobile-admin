import 'package:bayan_rme/features/auth/data/auth_api.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _onShip = AppUser(
  id: 'u1',
  name: 'Lab',
  email: 'lab@example.com',
  role: UserRole.lab,
  shipId: 'ship-1',
  shipCode: 'KAPAL-01',
  shipName: 'KM Bayan 01',
);

/// A session saved at login, and what the server says about the user now
/// (null: the server can't be reached).
class _Repository implements AuthRepository {
  _Repository(this.serverUser);

  AppUser? serverUser;

  @override
  Future<AuthSession?> restoreSession() async =>
      const AuthSession(token: 't', user: _onShip);

  @override
  Future<AuthSession?> refreshUser(AuthSession current) async =>
      serverUser == null
      ? null
      : AuthSession(token: current.token, user: serverUser!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AuthController> _opened(_Repository repository) async {
  final controller = AuthController(repository);
  addTearDown(controller.dispose);
  await pumpEventQueue();
  return controller;
}

void main() {
  test(
    'a user taken off their ship no longer shows it after the app opens',
    () async {
      final controller = await _opened(
        _Repository(
          const AppUser(
            id: 'u1',
            name: 'Lab',
            email: 'lab@example.com',
            role: UserRole.lab,
          ),
        ),
      );

      final user = controller.state.session!.user;
      expect(user.shipId, isNull);
      expect(user.shipCode, isNull);
      expect(controller.state.session!.token, 't');
    },
  );

  test('offline, the user saved at login stays', () async {
    final controller = await _opened(_Repository(null));

    expect(controller.state.session!.user, _onShip);
  });

  group('AuthApi.me', () {
    AuthApi api(Response<dynamic> Function(RequestOptions) answer) => AuthApi(
      dio: Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(answer(options)),
          ),
        ),
    );

    test('reads the user and their ship', () async {
      final user = await api(
        (o) => Response(
          requestOptions: o,
          statusCode: 200,
          data: {
            'result': {
              'id': 'u1',
              'full_name': 'Lab',
              'email': 'lab@example.com',
              'role': 'Lab',
              'ship_id': 'ship-2',
              'ship': {
                'id': 'ship-2',
                'code': 'KAPAL-02',
                'name': 'KM Bayan 02',
              },
            },
          },
        ),
      ).me();

      expect(user?.shipCode, 'KAPAL-02');
      expect(user?.shipName, 'KM Bayan 02');
    });

    test("ignores the device's copy answered while offline", () async {
      final user = await api(
        (o) => Response(
          requestOptions: o,
          statusCode: 200,
          extra: {'fromCache': true},
          data: {
            'result': {'id': 'u1', 'email': 'lab@example.com', 'role': 'Lab'},
          },
        ),
      ).me();

      expect(user, isNull);
    });
  });
}
