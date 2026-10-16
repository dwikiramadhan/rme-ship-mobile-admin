import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // debugPrint is not stripped from release builds; silence it there so API
  // payloads (incl. patient data) never reach device logs.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  await ApiConfig.init();
  await _initFirebase();
  runApp(const ProviderScope(child: BayanRmeApp()));
}

/// Firebase (push notifications) reads its config from
/// android/app/google-services.json. iOS has no GoogleService-Info.plist yet,
/// so it fails there; the app then runs without push.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('⚠️ [Firebase] not initialized, push disabled: $e');
  }
}
