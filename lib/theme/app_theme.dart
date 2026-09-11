import 'package:flutter/material.dart';

/// ===============================================================
/// APP COLORS
/// ===============================================================
/// Palet warna utama aplikasi Patroli Security.
/// Tema: Dark Navy / Command Center
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------
  // PRIMARY
  // ---------------------------------------------------------------
  static const Color primary = Color(0xFF2F6FED);
  static const Color primaryDark = Color(0xFF1B3F91);
  static const Color primaryLight = Color(0xFF1E2A4A);

  // ---------------------------------------------------------------
  // ACCENT
  // ---------------------------------------------------------------
  // Teal digunakan untuk aksi scan QR, tamu, dan beberapa CTA.
  static const Color accent = Color(0xFF14B8A6);
  static const Color accentDark = Color(0xFF0E7C70);

  // ---------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFEF4444);

  // ---------------------------------------------------------------
  // BACKGROUND
  // ---------------------------------------------------------------
  static const Color bg = Color(0xFF10151D);
  static const Color surface = Color(0xFF1A212C);
  static const Color surfaceAlt = Color(0xFF212938);

  // ---------------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF3F5F8);
  static const Color textSecondary = Color(0xFF9AA4B2);

  // ---------------------------------------------------------------
  // BORDER
  // ---------------------------------------------------------------
  static const Color border = Color(0xFF2A3341);
}

/// ===============================================================
/// APP SHADOW
/// ===============================================================
class AppShadow {
  AppShadow._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
}

/// ===============================================================
/// APP THEME
/// ===============================================================
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      // -----------------------------------------------------------
      // BASIC
      // -----------------------------------------------------------
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',

      scaffoldBackgroundColor: AppColors.bg,

      // -----------------------------------------------------------
      // COLOR SCHEME
      // -----------------------------------------------------------
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.accentDark,
        onSecondaryContainer: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.border,
      ),

      // -----------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      // -----------------------------------------------------------
      // CARD
      // -----------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.border,
          ),
        ),
      ),

      // -----------------------------------------------------------
      // INPUT / TEXT FIELD
      // -----------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        helperStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 11.5,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.danger,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
      ),

      // -----------------------------------------------------------
      // TEXT THEME
      // -----------------------------------------------------------
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
        ),
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
        ),
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
        ),
        labelMedium: TextStyle(
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          color: AppColors.textSecondary,
        ),
      ),

      // -----------------------------------------------------------
      // DIALOG
      // -----------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // -----------------------------------------------------------
      // ELEVATED BUTTON
      // -----------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          minimumSize: const Size(
            0,
            50,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -----------------------------------------------------------
      // OUTLINED BUTTON
      // -----------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(
            color: AppColors.primary,
          ),
          minimumSize: const Size(
            0,
            50,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -----------------------------------------------------------
      // TEXT BUTTON
      // -----------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -----------------------------------------------------------
      // FLOATING ACTION BUTTON
      // -----------------------------------------------------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // -----------------------------------------------------------
      // BOTTOM NAVIGATION BAR
      // -----------------------------------------------------------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
        ),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // -----------------------------------------------------------
      // NAVIGATION BAR MATERIAL 3
      // -----------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),

      // -----------------------------------------------------------
      // CHIP
      // -----------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        disabledColor: AppColors.surfaceAlt,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.accent,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppColors.border,
          ),
        ),
      ),

      // -----------------------------------------------------------
      // SNACKBAR
      // -----------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // -----------------------------------------------------------
      // PROGRESS INDICATOR
      // -----------------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.border,
      ),

      // -----------------------------------------------------------
      // DIVIDER
      // -----------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // -----------------------------------------------------------
      // ICON
      // -----------------------------------------------------------
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
      ),

      // -----------------------------------------------------------
      // LIST TILE
      // -----------------------------------------------------------
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
        tileColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),

      // -----------------------------------------------------------
      // SWITCH
      // -----------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent;
            }

            return AppColors.textSecondary;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accentDark;
            }

            return AppColors.surfaceAlt;
          },
        ),
      ),

      // -----------------------------------------------------------
      // CHECKBOX
      // -----------------------------------------------------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }

            return Colors.transparent;
          },
        ),
        checkColor: WidgetStateProperty.all(
          Colors.white,
        ),
        side: const BorderSide(
          color: AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // -----------------------------------------------------------
      // RADIO
      // -----------------------------------------------------------
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }

            return AppColors.textSecondary;
          },
        ),
      ),

      // -----------------------------------------------------------
      // TOOLTIP
      // -----------------------------------------------------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
        ),
      ),

      // -----------------------------------------------------------
      // SCROLLBAR
      // -----------------------------------------------------------
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          AppColors.border,
        ),
        radius: const Radius.circular(10),
      ),

      // -----------------------------------------------------------
      // PAGE TRANSITION / SPLASH
      // -----------------------------------------------------------
      splashFactory: InkRipple.splashFactory,

      splashColor: AppColors.primary.withValues(alpha: 0.12),

      highlightColor: AppColors.primary.withValues(alpha: 0.06),

      hoverColor: AppColors.primary.withValues(alpha: 0.06),

      dividerColor: AppColors.border,
    );
  }
}
