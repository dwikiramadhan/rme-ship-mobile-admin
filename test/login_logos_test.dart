import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/auth/presentation/auth_state.dart';
import 'package:bayan_rme/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The three logos at the top of the login screen stay inside their box on
// every screen size.

class _SignedOut extends StateNotifier<AuthState> implements AuthController {
  _SignedOut() : super(const AuthState.unauthenticated());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const screens = {
    'narrow phone (Fold, large display size)': Size(280, 653),
    'small phone': Size(320, 568),
    'phone': Size(360, 640),
    'iPhone': Size(390, 844),
    'large phone': Size(412, 915),
    'phone in landscape': Size(915, 412),
    'tablet': Size(800, 1280),
    'tablet in landscape': Size(1280, 800),
  };

  for (final MapEntry(key: name, value: size) in screens.entries) {
    testWidgets('logos fit their box: $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The test font is far wider than the app's: some text rows overflow
      // here that don't on a device. The logos are checked below.
      final reportError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) {
          reportError?.call(details);
        }
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _SignedOut()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      FlutterError.onError = reportError;

      final logos = find.byType(Image);
      expect(logos, findsNWidgets(3));
      final box = tester.getRect(
        find.ancestor(of: logos.first, matching: find.byType(Container)).first,
      );
      for (final logo in logos.evaluate()) {
        final rect = tester.getRect(find.byWidget(logo.widget));
        expect(
          box.inflate(0.5).contains(rect.topLeft) &&
              box.inflate(0.5).contains(rect.bottomRight),
          isTrue,
          reason: '$rect is outside the logo box $box',
        );
      }
    });
  }
}
