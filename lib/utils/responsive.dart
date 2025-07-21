import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobile = 320;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double largeDesktop = 1440;
}

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.tablet;
  }
  
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tablet &&
           MediaQuery.of(context).size.width < ResponsiveBreakpoints.desktop;
  }
  
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;
  }
  
  static double getResponsivePadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }
  
  static double getResponsiveCardPadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 20.0;
    return 24.0;
  }
  
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (isMobile(context)) return baseFontSize * 0.9;
    if (isTablet(context)) return baseFontSize;
    return baseFontSize * 1.1;
  }
  
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(8.0);
    if (isTablet(context)) return const EdgeInsets.all(16.0);
    return const EdgeInsets.all(24.0);
  }
}
