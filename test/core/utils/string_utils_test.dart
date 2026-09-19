/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/string_utils.dart';

void main() {
  group('StringUtils', () {
    test('capitalize returns capitalized string', () {
      expect(StringUtils.capitalize('hello'), 'Hello');
      expect(StringUtils.capitalize('WORLD'), 'WORLD');
      expect(StringUtils.capitalize(''), '');
      expect(StringUtils.capitalize('a'), 'A');
    });

    test('truncate returns truncated string with ellipsis', () {
      expect(
          StringUtils.truncate('This is a long string', 10), 'This is a ...');
      expect(StringUtils.truncate('Short', 10), 'Short');
      expect(StringUtils.truncate('', 10), '');
    });

    test('isValidEmail validates email correctly', () {
      expect(StringUtils.isValidEmail('test@example.com'), true);
      expect(StringUtils.isValidEmail('invalid-email'), false);
      expect(StringUtils.isValidEmail('test@example'), false);
      expect(StringUtils.isValidEmail('test@.com'), false);
      expect(StringUtils.isValidEmail(''), false);
    });

    test('isValidPassword validates password correctly', () {
      // Valid password: at least 8 characters, 1 uppercase, 1 lowercase, 1 number
      expect(StringUtils.isValidPassword('Password123'), true);
      expect(StringUtils.isValidPassword('short1A'), false); // Too short
      expect(StringUtils.isValidPassword('password123'), false); // No uppercase
      expect(StringUtils.isValidPassword('PASSWORD123'), false); // No lowercase
      expect(StringUtils.isValidPassword('Passwordabc'), false); // No number
      expect(StringUtils.isValidPassword(''), false);
    });

    test('formatPhoneNumber formats phone number correctly', () {
      expect(StringUtils.formatPhoneNumber('1234567890'), '(123) 456-7890');
      expect(StringUtils.formatPhoneNumber('123456789'),
          '123456789'); // Invalid length
      expect(StringUtils.formatPhoneNumber(''), '');
    });

    test('maskEmail masks email correctly', () {
      expect(StringUtils.maskEmail('test@example.com'), 't***@example.com');
      expect(StringUtils.maskEmail('a@b.com'), 'a***@b.com');
      expect(StringUtils.maskEmail(''), '');
    });
  });
}
