/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/network_utils.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('NetworkUtils', () {
    setUp(() {
      // No setup needed for these tests
    });

    test('isNetworkError identifies network errors correctly', () {
      expect(NetworkUtils.isNetworkError(Exception('Failed host lookup')), true);
      expect(NetworkUtils.isNetworkError(Exception('Connection refused')), true);
      expect(NetworkUtils.isNetworkError(Exception('Connection timed out')), true);
      expect(NetworkUtils.isNetworkError(Exception('Network is unreachable')), true);
      expect(NetworkUtils.isNetworkError(Exception('Other error')), false);
    });

    test('formatUrl formats URL correctly', () {
      expect(NetworkUtils.formatUrl('example.com', '/path'), 'https://example.com/path');
      expect(NetworkUtils.formatUrl('https://example.com', '/path'), 'https://example.com/path');
      expect(NetworkUtils.formatUrl('example.com', 'path'), 'https://example.com/path');
      expect(NetworkUtils.formatUrl('example.com/', '/path'), 'https://example.com/path');
    });

    test('getErrorMessage returns appropriate error message', () {
      expect(NetworkUtils.getErrorMessage(Exception('Failed host lookup')), 'No internet connection');
      expect(NetworkUtils.getErrorMessage(Exception('Connection refused')), 'Server is not responding');
      expect(NetworkUtils.getErrorMessage(Exception('Connection timed out')), 'Request timed out');
      expect(NetworkUtils.getErrorMessage(Exception('Other error')), 'An error occurred');
    });

    test('parseJson parses JSON correctly', () {
      const jsonString = '{"name": "John", "age": 30}';
      final result = NetworkUtils.parseJson(jsonString);
      expect(result, {'name': 'John', 'age': 30});

      // Our implementation returns null for invalid JSON instead of throwing
      expect(NetworkUtils.parseJson('invalid json'), isNull);
    });

    test('encodeQueryParameters encodes parameters correctly', () {
      final params = {'name': 'John Doe', 'age': '30'};
      expect(NetworkUtils.encodeQueryParameters(params), 'name=John%20Doe&age=30');
    });

    test('isSuccessStatusCode identifies success status codes correctly', () {
      expect(NetworkUtils.isSuccessStatusCode(200), true);
      expect(NetworkUtils.isSuccessStatusCode(201), true);
      expect(NetworkUtils.isSuccessStatusCode(204), true);
      expect(NetworkUtils.isSuccessStatusCode(400), false);
      expect(NetworkUtils.isSuccessStatusCode(404), false);
      expect(NetworkUtils.isSuccessStatusCode(500), false);
    });
  });
}
