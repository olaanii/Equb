import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class Breakpoints {
  static const double tablet = 640;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;

  static const double maxWidthDesktop = 1280;
  static const double maxWidthTablet = 960;
}

extension MediaQueryX on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => screenSize.width;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;
  bool get isLargeDesktop => screenWidth >= Breakpoints.largeDesktop;
  bool get isTablet =>
      screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.desktop;
  bool get isMobile => screenWidth < Breakpoints.tablet;

  double get contentMaxWidth {
    if (isLargeDesktop) return Breakpoints.maxWidthDesktop + 120;
    if (isDesktop) return Breakpoints.maxWidthDesktop;
    if (isTablet) return Breakpoints.maxWidthTablet;
    return screenWidth;
  }

  EdgeInsets get pagePadding {
    if (isLargeDesktop || isDesktop) return AppSpacing.pagePaddingDesktop;
    if (isTablet) return AppSpacing.pagePaddingTablet;
    return AppSpacing.pagePaddingMobile;
  }

  EdgeInsets get sectionPadding => EdgeInsets.symmetric(
    horizontal: isMobile ? AppSpacing.sm : AppSpacing.md,
    vertical: AppSpacing.md,
  );

  double responsiveValue({
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
