import 'package:flutter/widgets.dart';

class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 960;
  static const double expanded = 1280;
}

class Responsive {
  const Responsive._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppBreakpoints.compact && width < AppBreakpoints.medium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.expanded) return const EdgeInsets.symmetric(horizontal: 64);
    if (width >= AppBreakpoints.medium) return const EdgeInsets.symmetric(horizontal: 32);
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}
