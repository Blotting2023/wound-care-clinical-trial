import 'package:flutter/material.dart';

/// Design tokens & theme for the wound assessment app.
///
/// Source of truth: `UI设计/README.md` — Apple #00002 template,
/// Action Blue #0066CC, background #F5F5F7, white cards with 18px radius
/// and 1px light border, no shadows.
class AppTheme {
  AppTheme._();

  // ── Color tokens (design spec §3.2) ─────────────────────────────
  static const Color actionBlue = Color(0xFF0066CC);
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textHint = Color(0xFF9A9A9A);
  static const Color cardBorder = Color(0xFFE0E0E0);
  static const Color cardBackground = Colors.white;
  static const Color pageBackground = Color(0xFFF5F5F7);
  static const Color statusPendingSign = Color(0xFFFFA940); // 待签名 暖橙
  static const Color statusLocked = Color(0xFF52C41A); // 已锁定 绿
  static const Color noticeBackground = Color(0xFFF0F7FF); // 合规声明蓝底
  static const Color aiContour = Color(0xFFC0392B); // AI 分割轮廓红
  static const Color tissueGranulation = Color(0xFF52C41A); // 肉芽 绿
  static const Color tissueSlough = Color(0xFFFFA940); // 腐肉 橙
  static const Color tissueNecrosis = Color(0xFFFF4D4F); // 坏死 红
  static const Color error = Color(0xFFE5484D);

  // ── Typography (design spec §3.3) ───────────────────────────────
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.4,
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: textPrimary,
    height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: textSecondary,
    height: 1.5,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    color: textHint,
    height: 1.5,
  );
  static const TextStyle metricNumber = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );
  static const TextStyle timestamp = TextStyle(
    fontSize: 12,
    color: textSecondary,
    height: 1.4,
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: actionBlue,
        brightness: Brightness.light,
        primary: actionBlue,
        onPrimary: Colors.white,
        secondary: actionBlue,
        surface: cardBackground,
        error: error,
      ),
      scaffoldBackgroundColor: pageBackground,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: pageBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: title,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: actionBlue.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: actionBlue,
          side: const BorderSide(color: actionBlue, width: 1),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: actionBlue,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        hintStyle: const TextStyle(color: textHint, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: actionBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineMedium: display,
        titleLarge: title,
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: body,
        bodyMedium: caption,
        bodySmall: micro,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: cardBorder, thickness: 1),
    );
  }
}
