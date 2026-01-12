import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    final scheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.black,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.black,
      background: Color(0xFF0B0C0E),
      onBackground: Color(0xFFECEFF1),
      surface: Color(0xFF121316),
      onSurface: Color(0xFFECEFF1),
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      surfaceVariant: Color(0xFF1A1C1F),
      outline: Color(0xFF2A2E32),
    );
    return _baseTheme(scheme: scheme);
  }

  static ThemeData light() {
    final scheme = const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.black,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      background: Color(0xFFF3F5F7),
      onBackground: Color(0xFF0F172A),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A),
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      surfaceVariant: Color(0xFFF0F2F4),
      outline: Color(0xFFE3E7EA),
    );
    return _baseTheme(scheme: scheme, isDark: false);
  }

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    bool isDark = true,
  }) {
    final textTheme = TextTheme(
      displayLarge: AppTextStyles.headline1,
      displayMedium: AppTextStyles.headline2,
      titleLarge: AppTextStyles.headline2,
      bodyLarge: AppTextStyles.bodyText1,
      bodyMedium: AppTextStyles.bodyText2,
      labelLarge: AppTextStyles.button,
      labelSmall: AppTextStyles.label,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.surface,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadiuses.small),
        insetPadding: AppSpacing.pagePaddingMobile,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.headline2.copyWith(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: isDark ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadiuses.medium),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadiuses.small),
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith(
            (states) =>
                states.contains(MaterialState.disabled)
                    ? scheme.primary.withOpacity(0.4)
                    : scheme.primary,
          ),
          foregroundColor: MaterialStateProperty.all(scheme.onPrimary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadiuses.small),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: AppRadiuses.small),
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          backgroundColor: MaterialStateProperty.resolveWith(
            (states) =>
                states.contains(MaterialState.selected)
                    ? scheme.primary.withOpacity(0.2)
                    : scheme.surface,
          ),
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) =>
                states.contains(MaterialState.selected)
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadiuses.small,
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadiuses.small,
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadiuses.small,
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        hintStyle: AppTextStyles.bodyText2,
        labelStyle: AppTextStyles.label,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withOpacity(0.16),
        elevation: 8,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.all(AppTextStyles.label),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(MaterialState.selected)
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        elevation: 8,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 28),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurface.withOpacity(0.6),
          size: 24,
        ),
        selectedLabelTextStyle: AppTextStyles.bodyText1,
        unselectedLabelTextStyle: AppTextStyles.bodyText2,
        indicatorColor: scheme.primary.withOpacity(0.16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceMuted : scheme.primary.withOpacity(0.1),
        labelStyle: AppTextStyles.label,
        selectedColor: scheme.primary.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: StadiumBorder(
          side: BorderSide(color: scheme.primary.withOpacity(0.4)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withOpacity(0.3),
        thickness: 1,
        space: 24,
      ),
    );
  }
}
