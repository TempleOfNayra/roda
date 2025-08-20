import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Brightness;
import 'package:roda/core/theme/roda_colors.dart';

class IOSTheme {
  IOSTheme._();

  static const CupertinoThemeData lightTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: RodaColors.activeBlue,
    primaryContrastingColor: RodaColors.white,
    barBackgroundColor: RodaColors.systemBackground,
    scaffoldBackgroundColor: RodaColors.systemBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: RodaColors.label,
      navTitleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: RodaColors.label,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: RodaColors.label,
      ),
    ),
  );

  static const CupertinoThemeData darkTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: RodaColors.activeBlue,
    primaryContrastingColor: RodaColors.white,
    barBackgroundColor: RodaColors.systemBackground,
    scaffoldBackgroundColor: RodaColors.systemBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: RodaColors.label,
      navTitleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: RodaColors.label,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: RodaColors.label,
      ),
    ),
  );
}