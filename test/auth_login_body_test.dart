import 'package:flutter_test/flutter_test.dart';
import 'package:bayan_rme/features/auth/data/auth_api.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';

void main() {
  group('AuthApi.loginBody', () {
    test('sends a username in the username field', () {
      expect(AuthApi.loginBody('ners.siti', 'rahasia'), {'username': 'ners.siti', 'password': 'rahasia'});
    });

    test('sends an email in the email field', () {
      expect(AuthApi.loginBody('siti@rme.id', 'rahasia'), {'email': 'siti@rme.id', 'password': 'rahasia'});
    });
  });

  test('AppUser keeps the username and allows an empty email', () {
    final user = AppUser.fromJson(const {
      'id': 'u1',
      'full_name': 'Ners Siti',
      'username': 'ners.siti',
      'email': '',
      'role': 'Perawat',
    });
    expect(user.username, 'ners.siti');
    expect(user.email, '');
    expect(AppUser.fromJson(user.toJson()), user);
  });
}
