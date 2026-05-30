import 'package:flutter/material.dart';

class Responsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double maxContentWidth = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    if (isTablet(context)) return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    return const EdgeInsets.all(12);
  }

  // Títulos de cards
  static double cardTitleSize(BuildContext context) {
    if (isDesktop(context)) return 15;
    if (isTablet(context)) return 14;
    return 12;
  }

  // Subtítulos de cards
  static double cardSubtitleSize(BuildContext context) {
    if (isDesktop(context)) return 13;
    if (isTablet(context)) return 12;
    return 10;
  }

  // Número de stock
  static double stockNumberSize(BuildContext context) {
    if (isDesktop(context)) return 24;
    if (isTablet(context)) return 20;
    return 16;
  }

  // Chips de estado
  static double chipFontSize(BuildContext context) {
    if (isDesktop(context)) return 11;
    if (isTablet(context)) return 11;
    return 9;
  }

  // Títulos de pantalla
  static double titleSize(BuildContext context) {
    if (isDesktop(context)) return 28;
    if (isTablet(context)) return 24;
    return 20;
  }

  static double bodySize(BuildContext context) {
    if (isDesktop(context)) return 16;
    if (isTablet(context)) return 15;
    return 14;
  }

  // Padding interno de cards
  static EdgeInsets cardPadding(BuildContext context) {
    if (isTabletOrDesktop(context)) return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  // Radio del avatar en cards
  static double avatarRadius(BuildContext context) {
    if (isTabletOrDesktop(context)) return 22;
    return 16;
  }

  static Widget maxWidth({required Widget child, double maxWidth = maxContentWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}