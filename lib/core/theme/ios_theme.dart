import 'package:flutter/cupertino.dart';

class IOSTheme {
  IOSTheme._();

  static const CupertinoThemeData theme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: CupertinoColors.activeBlue,
    primaryContrastingColor: CupertinoColors.white,
    barBackgroundColor: CupertinoColors.systemBackground,
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: CupertinoColors.label,
      textStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        letterSpacing: -0.41,
        color: CupertinoColors.label,
      ),
      actionTextStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        letterSpacing: -0.41,
        color: CupertinoColors.activeBlue,
      ),
      tabLabelTextStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 10,
        letterSpacing: -0.24,
        color: CupertinoColors.inactiveGray,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: CupertinoColors.label,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.41,
        color: CupertinoColors.label,
      ),
      navActionTextStyle: TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: 17,
        letterSpacing: -0.41,
        color: CupertinoColors.activeBlue,
      ),
      pickerTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 21,
        letterSpacing: -0.41,
        color: CupertinoColors.label,
      ),
      dateTimePickerTextStyle: TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: 21,
        color: CupertinoColors.label,
      ),
    ),
  );
  
  // Custom colors for the app
  static const Color primaryBlue = CupertinoColors.activeBlue;
  static const Color destructiveRed = CupertinoColors.destructiveRed;
  static const Color successGreen = CupertinoColors.systemGreen;
  static const Color warningOrange = CupertinoColors.systemOrange;
  static const Color surfaceColor = CupertinoColors.systemBackground;
  static const Color groupedBackground = CupertinoColors.systemGroupedBackground;
  static const Color separator = CupertinoColors.separator;
  static const Color secondaryLabel = CupertinoColors.secondaryLabel;
  static const Color tertiaryLabel = CupertinoColors.tertiaryLabel;
}