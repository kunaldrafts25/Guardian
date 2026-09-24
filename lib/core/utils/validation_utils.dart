/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

/// A utility class for validating user input
class ValidationUtils {
  /// Validates a name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(value)) {
      return 'Name should only contain letters';
    }

    return null;
  }

  /// Validates an email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    if (!isValidEmail(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  /// Validates a password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validates a phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove non-numeric characters for validation
    final numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericValue.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }

    return null;
  }

  /// Validates a confirm password field
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validates a required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  /// Validates an age field
  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return 'Age is required';
    }

    final age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid age';
    }

    if (age < 13) {
      return 'You must be at least 13 years old';
    }

    if (age > 100) {
      return 'Please enter a valid age';
    }

    return null;
  }

  /// Checks if an email is valid
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Checks if a password is valid
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;

    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    // Check for at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;

    return true;
  }

  /// Checks if a phone number is valid
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;

    // Remove non-numeric characters for validation
    final numericValue = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Check if the phone number has a valid length (between 10 and 15 digits)
    return numericValue.length >= 10 && numericValue.length <= 15;
  }

  /// Checks if a name is valid
  static bool isValidName(String name) {
    if (name.isEmpty || name.length < 2) return false;

    // Allow letters, spaces, hyphens, and apostrophes
    return RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(name);
  }

  /// Checks if an address is valid
  static bool isValidAddress(String address) {
    if (address.isEmpty || address.length < 5) return false;

    // Address should contain at least one letter and one number
    return RegExp(r'[a-zA-Z]').hasMatch(address) &&
        RegExp(r'[0-9]').hasMatch(address);
  }

  /// Checks if a zip code is valid
  static bool isValidZipCode(String zipCode) {
    if (zipCode.isEmpty) return false;

    // US ZIP code (5 digits or 5+4)
    if (RegExp(r'^\d{5}(-\d{4})?$').hasMatch(zipCode)) return true;

    // Canadian postal code (A1A 1A1)
    if (RegExp(r'^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$').hasMatch(zipCode)) {
      return true;
    }

    return false;
  }
}
