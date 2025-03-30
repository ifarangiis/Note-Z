import 'package:flutter/material.dart';

class ColorUtil {
  // App theme colors
  static const Color primary = Color(0xFFFF4EC0);       // Pink
  static const Color primaryLight = Color(0xFFFF8FCB);  // Light Pink
  static const Color secondary = Color(0xFF6A35FC);     // Purple (original primary)
  static const Color tertiary = Color(0xFF00E1B9);      // Teal
  
  // Gradient colors for app theme
  static const List<Color> primaryGradient = [
    Color(0xFFFF4EC0),
    Color(0xFFFF8FCB),
  ];
  
  static const List<Color> accentGradient = [
    Color(0xFF6A35FC),
    Color(0xFF8F65FF),
  ];
  
  // Background gradients
  static const List<Color> backgroundGradient = [
    Color(0xFFFFF0F7),
    Color(0xFFFFFFFF),
  ];
  
  // Text colors
  static const Color textDark = Color(0xFF303044);
  static const Color textMuted = Color(0xFF9E9EBF);
  
  // Deadline urgency colors
  static const Color noPriority = Color(0xFF9E9EBF);
  static const Color lowPriority = Color(0xFF54D3AD);
  static const Color mediumPriority = Color(0xFFFFB443);
  static const Color highPriority = Color(0xFFFF6B6B);
  static const Color pastDue = Color(0xFFFF4757);
  
  // Get color based on urgency level
  static Color getUrgencyColor(int urgencyLevel) {
    switch (urgencyLevel) {
      case 1:
        return lowPriority;
      case 2:
        return mediumPriority;
      case 3:
        return highPriority;
      case 4:
        return pastDue;
      default:
        return noPriority;
    }
  }
  
  // Get gradient based on urgency level
  static List<Color> getUrgencyGradient(int urgencyLevel) {
    switch (urgencyLevel) {
      case 1:
        return [lowPriority, lowPriority.withOpacity(0.7)];
      case 2:
        return [mediumPriority, mediumPriority.withOpacity(0.7)];
      case 3:
        return [highPriority, highPriority.withOpacity(0.7)];
      case 4:
        return [pastDue, pastDue.withOpacity(0.7)];
      default:
        return [noPriority, noPriority.withOpacity(0.7)];
    }
  }
  
  // Color palette for notes
  static const List<Color> notePalette = [
    Color(0xFFFF4EC0), // Pink (primary)
    Color(0xFF54D3AD), // Teal
    Color(0xFF6A35FC), // Purple
    Color(0xFF00A8E8), // Blue
    Color(0xFFFFB443), // Orange
    Color(0xFFFF8FCB), // Light Pink
    Color(0xFF08A88A), // Green
    Color(0xFFFF6B6B), // Red
  ];
  
  // Get a random color from the note palette
  static Color getRandomNoteColor() {
    final index = DateTime.now().microsecond % notePalette.length;
    return notePalette[index];
  }
} 