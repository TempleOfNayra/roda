import 'package:flutter/cupertino.dart';

class RodaColors {
  // Primary - Main CTAs and active states
  static const primary = Color(0xFFC9302C);        // Deep Crimson
  static const primaryLight = Color(0xFFE85D04);   // Lighter orange-red
  
  // Secondary - Supporting actions
  static const secondary = Color(0xFFEC971F);      // Burnt Gold
  static const secondaryDark = Color(0xFFB8860B);  // Darker gold
  
  // Neutral - UI structure
  static const neutral = Color(0xFF2B3E50);        // Midnight Blue
  static const neutralLight = Color(0xFF34495E);   // Lighter blue-gray
  
  // Backgrounds
  static const background = Color(0xFFF8F5F0);     // Warm ivory
  static const surface = Color(0xFFFFFFFF);        // Pure white
  static const surfaceAlt = Color(0xFFFAF9F7);     // Off-white
  
  // Text
  static const textPrimary = Color(0xFF1C1C1C);    // Rich black
  static const textSecondary = Color(0xFF6C757D);  // Medium gray
  static const textHint = Color(0xFF9E9E9E);       // Light gray
  
  // System
  static const success = Color(0xFF1A5F4A);        // Forest green
  static const error = Color(0xFFDC3545);          // Error red
  static const divider = Color(0xFFE0E0E0);        // Subtle dividers
  static const live = Color(0xFF00D9A3);           // Live indicator
  
  // Additional colors for Cupertino replacements
  static const white = Color(0xFFFFFFFF);          // Pure white
  static const black = Color(0xFF000000);          // Pure black
  static const transparent = Color(0x00000000);    // Transparent
  static const systemGrey = Color(0xFF8E8E93);     // System grey
  static const systemGrey2 = Color(0xFFAEAEB2);    // System grey 2
  static const systemGrey3 = Color(0xFFC7C7CC);    // System grey 3
  static const systemGrey4 = Color(0xFFD1D1D6);    // System grey 4
  static const systemGrey5 = Color(0xFFE5E5EA);    // System grey 5
  static const systemGrey6 = Color(0xFFF2F2F7);    // System grey 6
  static const activeBlue = Color(0xFF007AFF);     // iOS blue
  static const destructiveRed = error;             // Use error red for destructive actions
  static const label = textPrimary;                // Main text color
  static const secondaryLabel = textSecondary;     // Secondary text color
  static const tertiaryLabel = textHint;           // Tertiary text color
  static const systemBackground = background;      // System background
  static const secondarySystemBackground = surfaceAlt; // Secondary background
  static const systemGroupedBackground = background;   // Grouped background
  static const separator = divider;                // Separator color
}