import 'package:flutter/material.dart';
import 'package:retro/ui/theme/colors.dart';

ThemeData lightTHeme() {
  return ThemeData.light(); // TODO
}

ThemeData darkTheme() {
  final ThemeData base = ThemeData.dark();
  ColorScheme test = base.colorScheme.copyWith(
    primary: RetroColors.telegramBlue,
    onPrimary: Colors.white,
    secondary: RetroColors.elephant,
    onSecondary: Colors.white,
    surface: RetroColors.bigStone,
    error: RetroColors.wildWatermelon,
  );

  return base.copyWith(
    colorScheme: test,
  );
}
