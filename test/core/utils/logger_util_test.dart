/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/logger.dart';

void main() {
  group('Logger', () {
    test('info logs message correctly', () {
      // This test is more of a smoke test since we can't easily verify debug output
      // It just ensures the method doesn't throw an exception
      expect(() => Logger.info('Test info message'), returnsNormally);
    });

    test('debug logs message correctly', () {
      expect(() => Logger.debug('Test debug message'), returnsNormally);
    });

    test('warning logs message correctly', () {
      expect(() => Logger.warning('Test warning message'), returnsNormally);
    });

    test('error logs message correctly', () {
      expect(() => Logger.error('Test error message'), returnsNormally);
    });

    test('error logs message with error details correctly', () {
      final error = Exception('Test error');
      expect(() => Logger.error('Test error message', error), returnsNormally);
    });

    test('error logs message with error and stack trace correctly', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      expect(
        () => Logger.error('Test error message', error, stackTrace),
        returnsNormally,
      );
    });
  });
}
