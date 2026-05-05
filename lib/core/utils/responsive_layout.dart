import 'package:flutter/material.dart';

/// Breakpoints for adaptive layout.
/// Phone  : width < 600
/// Tablet : 600 <= width < 900
/// Wide   : width >= 900  (tablet landscape, desktop)
class ResponsiveLayout {
  const ResponsiveLayout._();

  static const double _tabletBreakpoint = 600;
  static const double _wideBreakpoint = 900;

  /// Maximum content width for centered layouts on large screens.
  static const double maxContentWidth = 960;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _tabletBreakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  /// Number of grid columns for video feed cards.
  static int feedColumnCount(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= _wideBreakpoint) return 3;
    if (w >= _tabletBreakpoint) return 2;
    return 1;
  }

  /// Horizontal page padding — wider on large screens.
  static double pagePadding(BuildContext context) =>
      isWide(context) ? 32 : 16;
}

/// Centers and constrains [child] to [maxWidth] on large screens.
class ConstrainedPage extends StatelessWidget {
  const ConstrainedPage({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
