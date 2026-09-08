import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_config.dart';
import 'core/network/server_discovery.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  unawaited(ServerDiscovery.autoDiscover());
  runApp(const ProviderScope(child: BayanRmeApp()));
}
