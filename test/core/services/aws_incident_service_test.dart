/*
 * Guardian - AWS Incident Service Unit Tests
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/aws_incident_service.dart';

void main() {
  group('AwsIncidentService', () {
    late AwsIncidentService service;

    setUp(() {
      service = AwsIncidentService.instance;
    });

    test('Singleton instance is non-null', () {
      expect(service, isNotNull);
      expect(AwsIncidentService(), same(service));
    });

    test('BaseUrl is non-empty and well-formed', () {
      final url = service.baseUrl;
      expect(url, isNotEmpty);
      expect(url.startsWith('http://') || url.startsWith('https://'), isTrue);
    });
  });
}
