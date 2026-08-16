import 'package:flutter/widgets.dart';

/// The prototype was designed for a fixed 1100x780 tablet canvas with a side
/// nav rail and master-detail lists. Below this shortest-side threshold we
/// fall back to a phone layout (bottom tabs, single-pane push navigation).
const double kTabletShortestSideBreakpoint = 600;

bool isTabletLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final shortestSide = size.width < size.height ? size.width : size.height;
  return shortestSide >= kTabletShortestSideBreakpoint;
}

double getAdaptiveTextScale(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final shortestSide = size.width < size.height ? size.width : size.height;
  if (shortestSide >= 900) {
    return 1.20;
  } else if (shortestSide >= kTabletShortestSideBreakpoint) {
    return 1.14;
  }
  return 1.0;
}

