import 'package:flutter/material.dart';

/// Global root navigator key to allow top-level navigation operations
/// (e.g. popping modals/sub-routes on session expiration / unauthorized).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
