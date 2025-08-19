import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FormTheme {
  // Label styles
  static const labelColor = Color(0xFF6B7280); // Medium gray
  static const labelFontSize = 14.0;
  static const labelFontWeight = FontWeight.w500;
  
  static const labelStyle = TextStyle(
    color: labelColor,
    fontSize: labelFontSize,
    fontWeight: labelFontWeight,
  );
  
  // Input text styles
  static const inputTextColor = Colors.black;
  static const inputTextSize = 16.0;
  static const inputPlaceholderColor = Color(0xFF9CA3AF); // Light gray
  
  static const inputTextStyle = TextStyle(
    color: inputTextColor,
    fontSize: inputTextSize,
  );
  
  static const placeholderStyle = TextStyle(
    color: inputPlaceholderColor,
    fontSize: inputTextSize,
  );
  
  // Field decoration
  static final fieldDecoration = BoxDecoration(
    color: CupertinoColors.tertiarySystemFill,
    borderRadius: BorderRadius.circular(8),
  );
  
  static const fieldPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  
  // Spacing
  static const labelSpacing = 8.0;
  static const fieldSpacing = 20.0;
  static const sectionSpacing = 24.0;
}