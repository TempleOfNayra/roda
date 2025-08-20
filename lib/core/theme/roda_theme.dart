import 'package:flutter/cupertino.dart';
import 'roda_colors.dart';

class RodaTheme {
  static CupertinoThemeData get theme => const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: RodaColors.primary,
    primaryContrastingColor: RodaColors.white,
    scaffoldBackgroundColor: RodaColors.background,
    barBackgroundColor: RodaColors.surface,
    textTheme: CupertinoTextThemeData(
      primaryColor: RodaColors.textPrimary,
      textStyle: TextStyle(
        inherit: true,
        color: RodaColors.textPrimary,
        fontSize: 16,
      ),
      navTitleTextStyle: TextStyle(
        inherit: true,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: RodaColors.neutral,
      ),
    ),
  );
  
  // Common styles
  static const cardDecoration = BoxDecoration(
    color: RodaColors.surface,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    boxShadow: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.08),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );
  
  static const primaryButton = BoxDecoration(
    color: RodaColors.primary,
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  
  static const secondaryButton = BoxDecoration(
    color: RodaColors.surface,
    borderRadius: BorderRadius.all(Radius.circular(8)),
    border: Border.fromBorderSide(
      BorderSide(color: RodaColors.primary, width: 1),
    ),
  );
}