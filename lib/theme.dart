import 'package:flutter/material.dart';

/// Colors used everywhere in the app. Change them here to restyle ServerDeck.
class AppColors {
  static const bg = Color(0xFF0A101C);
  static const card = Color(0xFF121A2A);
  static const cardHigh = Color(0xFF1A2640);
  static const accent = Color(0xFF3DDBC0); // teal
  static const accent2 = Color(0xFF7C8CFF); // soft blue-violet
  static const good = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const bad = Color(0xFFF87171);
  static const text = Color(0xFFE6EDF7);
  static const muted = Color(0xFF8A97AD);
  static const onAccent = Color(0xFF00201A);
}

/// Green below 75%, amber from 75%, red from 90%.
Color statusColor(num percent) {
  if (percent >= 90) return AppColors.bad;
  if (percent >= 75) return AppColors.warn;
  return AppColors.good;
}

const accentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.accent, AppColors.accent2],
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.accent2,
    surface: AppColors.bg,
    error: AppColors.bad,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    useMaterial3: true,
  );
}

/// The look of every text field.
InputDecoration fieldDecoration(
  String label, {
  String? hint,
  Widget? suffix,
  IconData? icon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: AppColors.card,
    border: border(Colors.white.withValues(alpha: 0.08)),
    enabledBorder: border(Colors.white.withValues(alpha: 0.08)),
    focusedBorder: border(AppColors.accent, 1.5),
  );
}
