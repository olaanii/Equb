import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette inspired by modern green fintech dashboards.
class AppColors {
  // Neopay-style lime accent.
  // Design: Lime Burst (#C3FF4E)
  static const Color primary = Color(0xFFC3FF4E);
  static const Color primaryDark = Color(0xFF0B0F0C);
  static const Color primaryLight = Color(0xFFD9FF6B);

  // Neutral secondary for dark pills/controls.
  static const Color secondary = Color(0xFF141414);
  static const Color accent = Color(0xFF5B9BFF);

  static const Color background = Color(0xFF050B06);
  static const Color backgroundDark = background;
  static const Color surface = Color(0xFF0B160C);
  static const Color surfaceBright = Color(0xFF142618);
  static const Color surfaceBrightDark = surfaceBright;
  static const Color surfaceMuted = Color(0xFF1F3322);
  static const Color border = Color(0xFF233828);
  static const Color slightlyLighterSurface = surfaceBright;

  static const Color textPrimary = Color(0xFFE6F2E7);
  static const Color textSecondary = Color(0xFF9EB6A5);
  static const Color textMuted = Color(0xFF6A7C6E);

  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF6C344);
  static const Color error = Color(0xFFFF5D5D);
  static const Color info = Color(0xFF4BA3FF);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3FA814), Color(0xFF1F4400)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy greyscale accessors for backwards compatibility during the refresh.
  static const Color grey1 = Color(0xFFE6F2E7);
  static const Color grey2 = Color(0xFFCFE1D5);
  static const Color grey3 = Color(0xFF9EB6A5);
  static const Color grey4 = textSecondary;
  static const Color grey5 = Color(0xFF2C3A30);
}

class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double gutter = 24;

  static const EdgeInsets pagePaddingMobile = EdgeInsets.symmetric(
    horizontal: 11,
    vertical: 16,
  );
  static const EdgeInsets pagePaddingTablet = EdgeInsets.symmetric(
    horizontal: 32,
    vertical: 24,
  );
  static const EdgeInsets pagePaddingDesktop = EdgeInsets.symmetric(
    horizontal: 48,
    vertical: 32,
  );
}

class AppRadiuses {
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(20));
}

class AppTextStyles {
  static const String displayFontFamily = 'SpaceGrotesk';
  static const String bodyFontFamily = 'Manrope';
  static const String fontFamily = bodyFontFamily;

  static final TextStyle headline1 = GoogleFonts.spaceGrotesk(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static final TextStyle headline2 = GoogleFonts.spaceGrotesk(
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle bodyText1 = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle bodyText2 = GoogleFonts.manrope(fontSize: 14);

  static final TextStyle label = GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  static final TextStyle button = GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
