/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:intl/intl.dart';

/// A utility class for date and time operations
class DateUtils {
  /// Formats a date using the specified format (default: dd/MM/yyyy)
  static String formatDate(DateTime? date, {String format = 'dd/MM/yyyy'}) {
    if (date == null) return '';
    return DateFormat(format).format(date);
  }
  
  /// Formats a time using the specified format (default: HH:mm)
  static String formatTime(DateTime? time, {String format = 'HH:mm'}) {
    if (time == null) return '';
    return DateFormat(format).format(time);
  }
  
  /// Formats a date and time using the specified format (default: dd/MM/yyyy HH:mm)
  static String formatDateTime(DateTime? dateTime, {String format = 'dd/MM/yyyy HH:mm'}) {
    if (dateTime == null) return '';
    return DateFormat(format).format(dateTime);
  }
  
  /// Returns a relative time string (e.g., "5 minutes ago", "Yesterday")
  static String getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
  
  /// Returns a relative time string (e.g., "5 minutes ago", "Yesterday")
  /// with more detailed formatting for older dates
  static String getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      // For older dates, return a formatted date
      return formatDate(dateTime, format: 'MMM d, yyyy');
    }
  }
  
  /// Checks if a date is today
  static bool isToday(DateTime? date) {
    if (date == null) return false;
    
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  /// Checks if two dates are the same day
  static bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
  
  /// Gets the difference in days between two dates
  static int getDaysDifference(DateTime date1, DateTime date2) {
    // Remove time component for accurate day calculation
    final d1 = DateTime(date1.year, date1.month, date1.day);
    final d2 = DateTime(date2.year, date2.month, date2.day);
    
    return d2.difference(d1).inDays;
  }
  
  /// Gets the start of the day (midnight) for a given date
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  /// Gets the end of the day (23:59:59.999) for a given date
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
  
  /// Gets the start of the week (Sunday) for a given date
  static DateTime startOfWeek(DateTime date) {
    final daysToSubtract = date.weekday % 7;
    return startOfDay(date.subtract(Duration(days: daysToSubtract)));
  }
  
  /// Gets the end of the week (Saturday) for a given date
  static DateTime endOfWeek(DateTime date) {
    final daysToAdd = 6 - (date.weekday % 7);
    return endOfDay(date.add(Duration(days: daysToAdd)));
  }
  
  /// Gets the start of the month for a given date
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }
  
  /// Gets the end of the month for a given date
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }
  
  /// Gets the age in years from a birthdate
  static int getAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    // Adjust age if birthday hasn't occurred yet this year
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }
  
  /// Checks if a date is in the future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }
  
  /// Checks if a date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }
  
  /// Gets a list of dates between two dates (inclusive)
  static List<DateTime> getDatesBetween(DateTime startDate, DateTime endDate) {
    final dates = <DateTime>[];
    
    // Remove time component for accurate day calculation
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!currentDate.isAfter(end)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return dates;
  }
}
