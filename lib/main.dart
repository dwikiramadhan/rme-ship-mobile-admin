import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_config.dart';
import 'core/network/server_discovery.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // debugPrint is not stripped from release builds; silence it there so API
  // payloads (incl. patient data) never reach device logs.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  await ApiConfig.init();
  unawaited(ServerDiscovery.autoDiscover());
  runApp(const ProviderScope(child: BayanRmeApp()));
}
