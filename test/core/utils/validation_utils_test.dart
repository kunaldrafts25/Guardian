/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/validation_utils.dart';

void main() {
  group('ValidationUtils', () {
    test('validateName validates name correctly', () {
      expect(ValidationUtils.validateName('John Doe'), null); // Valid
      expect(ValidationUtils.validateName('J'),
          'Name must be at least 2 characters'); // Too short
      expect(ValidationUtils.validateName(''), 'Name is required'); // Empty
      expect(ValidationUtils.validateName('John123'),
          'Name should only contain letters'); // Contains numbers
    });

    test('validateEmail validates email correctly', () {
      expect(ValidationUtils.validateEmail('test@example.com'), null); // Valid
      expect(ValidationUtils.validateEmail(''), 'Email is required'); // Empty
      expect(ValidationUtils.validateEmail('invalid-email'),
          'Please enter a valid email'); // Invalid format
    });

    test('validatePassword validates password correctly', () {
      expect(ValidationUtils.validatePassword('Password123'), null); // Valid
      expect(ValidationUtils.validatePassword(''),
          'Password is required'); // Empty
      expect(ValidationUtils.validatePassword('short1A'),
          'Password must be at least 8 characters'); // Too short
      expect(ValidationUtils.validatePassword('password123'),
          'Password must contain at least one uppercase letter'); // No uppercase
      expect(ValidationUtils.validatePassword('PASSWORD123'),
          'Password must contain at least one lowercase letter'); // No lowercase
      expect(ValidationUtils.validatePassword('Passwordabc'),
          'Password must contain at least one number'); // No number
    });

    test('validatePhone validates phone number correctly', () {
      expect(ValidationUtils.validatePhone('1234567890'), null); // Valid
      expect(ValidationUtils.validatePhone(''),
          'Phone number is required'); // Empty
      expect(ValidationUtils.validatePhone('123456'),
          'Please enter a valid 10-digit phone number'); // Too short
      expect(ValidationUtils.validatePhone('abcdefghij'),
          'Please enter a valid 10-digit phone number'); // Not numeric
    });

    test('validateConfirmPassword validates confirm password correctly', () {
      expect(
          ValidationUtils.validateConfirmPassword('Password123', 'Password123'),
          null); // Match
      expect(ValidationUtils.validateConfirmPassword('', 'Password123'),
          'Confirm password is required'); // Empty
      expect(
          ValidationUtils.validateConfirmPassword('Password123', 'Password456'),
          'Passwords do not match'); // Don't match
    });

    test('validateRequired validates required field correctly', () {
      expect(ValidationUtils.validateRequired('Value', 'Field'),
          null); // Has value
      expect(ValidationUtils.validateRequired('', 'Field'),
          'Field is required'); // Empty
    });

    test('validateAge validates age correctly', () {
      expect(ValidationUtils.validateAge('18'), null); // Valid
      expect(ValidationUtils.validateAge(''), 'Age is required'); // Empty
      expect(ValidationUtils.validateAge('abc'),
          'Please enter a valid age'); // Not numeric
      expect(ValidationUtils.validateAge('12'),
          'You must be at least 13 years old'); // Too young
      expect(ValidationUtils.validateAge('120'),
          'Please enter a valid age'); // Too old
    });
  });
}
