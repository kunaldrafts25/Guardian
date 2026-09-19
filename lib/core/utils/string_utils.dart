/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:intl/intl.dart';

/// A utility class for string operations
class StringUtils {
  /// Capitalizes the first letter of a string
  static String capitalize(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Capitalizes the first letter of each word in a string
  static String capitalizeEachWord(String str) {
    if (str.isEmpty) return str;
    return str.split(' ').map((word) => capitalize(word)).join(' ');
  }

  /// Truncates a string to a specified length and adds an ellipsis
  static String truncate(String str, int maxLength, {String suffix = '...'}) {
    if (str.isEmpty || str.length <= maxLength) return str;
    return str.substring(0, maxLength) + suffix;
  }

  /// Removes HTML tags from a string
  static String removeHtmlTags(String str) {
    if (str.isEmpty) return str;
    return str.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Formats a phone number as (XXX) XXX-XXXX
  static String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return phoneNumber;

    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Check if it's a valid 10-digit US phone number
    if (digitsOnly.length == 10) {
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }

    // Return the original string if it's not a valid phone number
    return phoneNumber;
  }

  /// Masks an email address for privacy
  static String maskEmail(String email) {
    if (email.isEmpty) return email;

    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email; // Not a valid email

    final username = email.substring(0, atIndex);
    final domain = email.substring(atIndex);

    // Keep the first character of the username and mask the rest
    final maskedUsername = '${username[0]}***';

    return '$maskedUsername$domain';
  }

  /// Formats a number as currency
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Checks if a string is a valid email address
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// Checks if a string is a valid password
  static bool isValidPassword(String password) {
    if (password.isEmpty || password.length < 8) return false;

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;

    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    return true;
  }

  /// Generates initials from a name
  static String getInitials(String name) {
    if (name.isEmpty) return '';

    final nameParts = name.split(' ');
    if (nameParts.length == 1) {
      return name[0].toUpperCase();
    }

    return nameParts[0][0].toUpperCase() +
        nameParts[nameParts.length - 1][0].toUpperCase();
  }

  /// Converts a string to camelCase
  static String toCamelCase(String str) {
    if (str.isEmpty) return str;

    final words = str.split(RegExp(r'[^a-zA-Z0-9]'));
    final firstWord = words[0].toLowerCase();
    final remainingWords =
        words.sublist(1).map((word) => capitalize(word.toLowerCase())).join('');

    return firstWord + remainingWords;
  }

  /// Converts a string to snake_case
  static String toSnakeCase(String str) {
    if (str.isEmpty) return str;

    // Replace non-alphanumeric characters with underscores
    final result = str.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    // Replace uppercase letters with underscore + lowercase
    return result
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
  }
}
