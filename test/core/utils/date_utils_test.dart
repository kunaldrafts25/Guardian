/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/date_utils.dart';

void main() {
  group('DateUtils', () {
    test('formatDate formats date correctly', () {
      final date = DateTime(2023, 5, 15);
      expect(DateUtils.formatDate(date), '15/05/2023');
    });

    test('formatDateTime formats date and time correctly', () {
      final dateTime = DateTime(2023, 5, 15, 14, 30);
      expect(DateUtils.formatDateTime(dateTime), '15/05/2023 14:30');
    });

    test('formatTime formats time correctly', () {
      final time = DateTime(2023, 5, 15, 14, 30);
      expect(DateUtils.formatTime(time), '14:30');
    });

    test('getTimeAgo returns correct relative time', () {
      final now = DateTime.now();

      // Just now
      expect(DateUtils.getTimeAgo(now), 'Just now');

      // Minutes ago
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      expect(DateUtils.getTimeAgo(fiveMinutesAgo), '5 minutes ago');

      // Hours ago
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(DateUtils.getTimeAgo(twoHoursAgo), '2 hours ago');

      // Days ago
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      expect(DateUtils.getTimeAgo(threeDaysAgo), '3 days ago');

      // Weeks ago
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      expect(DateUtils.getTimeAgo(twoWeeksAgo), '2 weeks ago');

      // Months ago
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
      expect(DateUtils.getTimeAgo(threeMonthsAgo).contains('months ago'), isTrue);

      // Years ago
      final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);
      expect(DateUtils.getTimeAgo(twoYearsAgo), '2 years ago');
    });

    test('isToday returns true for today', () {
      final today = DateTime.now();
      expect(DateUtils.isToday(today), true);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateUtils.isToday(yesterday), false);
    });

    test('isSameDay returns true for same day', () {
      final date1 = DateTime(2023, 5, 15, 10, 30);
      final date2 = DateTime(2023, 5, 15, 14, 45);
      expect(DateUtils.isSameDay(date1, date2), true);

      final date3 = DateTime(2023, 5, 16, 10, 30);
      expect(DateUtils.isSameDay(date1, date3), false);
    });

    test('getDaysDifference returns correct difference', () {
      final date1 = DateTime(2023, 5, 15);
      final date2 = DateTime(2023, 5, 20);
      expect(DateUtils.getDaysDifference(date1, date2), 5);

      final date3 = DateTime(2023, 5, 10);
      expect(DateUtils.getDaysDifference(date1, date3), -5);
    });
  });
}
