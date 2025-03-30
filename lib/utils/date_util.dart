import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class DateUtil {
  // Format the date to a readable string
  static String formatDate(DateTime date) {
    return DateFormat('E, MMM d, yyyy').format(date);
  }

  // Format the time to a readable string
  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  // Format the date and time to a readable string
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} at ${formatTime(dateTime)}';
  }
  
  // Format a date with a short weekday name
  static String formatShortDay(DateTime date) {
    return DateFormat('E').format(date);
  }
  
  // Format a date to just the day with month
  static String formatDayMonth(DateTime date) {
    return DateFormat('MMM d').format(date);
  }
  
  // Format a deadline with relative time
  static String formatDeadline(DateTime? deadline) {
    if (deadline == null) return 'No deadline';
    
    final now = DateTime.now();
    final difference = deadline.difference(now);
    
    if (difference.isNegative) {
      final days = difference.inDays.abs();
      if (days == 0) return 'Overdue today';
      return days == 1 ? 'Overdue by 1 day' : 'Overdue by $days days';
    } else {
      final days = difference.inDays;
      if (days == 0) return 'Due today';
      return days == 1 ? 'Due tomorrow' : 'Due in $days days';
    }
  }

  // Get the start of the current week (Sunday)
  static DateTime startOfWeek() {
    final now = DateTime.now();
    // In Dart, weekday is 1-7 with Monday=1, Sunday=7
    // We need to find the previous Sunday (or today if it's Sunday)
    final daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
    return DateTime(now.year, now.month, now.day - daysToSubtract);
  }

  // Get the end of the current week (Saturday)
  static DateTime endOfWeek() {
    final now = DateTime.now();
    // Find the next Saturday (or today if it's Saturday)
    final daysToAdd = now.weekday == 6 ? 0 : (6 - now.weekday);
    return DateTime(now.year, now.month, now.day + daysToAdd, 23, 59, 59);
  }

  // Check if a date is within the current week
  static bool isWithinCurrentWeek(DateTime date) {
    final start = startOfWeek();
    final end = endOfWeek();
    return date.isAfter(start) && date.isBefore(end);
  }

  // Get days remaining until end of week
  static int daysRemainingInWeek() {
    final now = DateTime.now();
    // If it's Sunday, return 0 as notes will be purged
    if (now.weekday == 7) {
      return 0;
    }
    // Otherwise, return days until next Sunday
    return 7 - now.weekday;
  }
  
  // Get the color for day of week
  static Color colorForWeekday(int weekday) {
    switch (weekday) {
      case 1: // Monday
        return Colors.green.shade400;
      case 2: // Tuesday
        return Colors.blue.shade400;
      case 3: // Wednesday
        return Colors.purple.shade400;
      case 4: // Thursday
        return Colors.orange.shade400;
      case 5: // Friday
        return Colors.pink.shade400;
      case 6: // Saturday
        return Colors.teal.shade400;
      case 7: // Sunday
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }
  
  // Get emoji for weekday
  static String emojiForWeekday(int weekday) {
    switch (weekday) {
      case 1: return '🚀'; // Monday
      case 2: return '🌟'; // Tuesday
      case 3: return '🔥'; // Wednesday
      case 4: return '💫'; // Thursday
      case 5: return '🎉'; // Friday
      case 6: return '✨'; // Saturday
      case 7: return '🌈'; // Sunday
      default: return '📅';
    }
  }
  
  // Group dates by weekday
  static Map<int, List<DateTime>> groupByWeekday(List<DateTime> dates) {
    final Map<int, List<DateTime>> result = {};
    
    // Initialize all weekdays with empty lists
    for (int i = 1; i <= 7; i++) {
      result[i] = [];
    }
    
    // Add dates to corresponding weekdays
    for (final date in dates) {
      result[date.weekday]!.add(date);
    }
    
    return result;
  }
} 