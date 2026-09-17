/*
 * Guardian - Risk Engine Dart Unit Tests
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/ai_service.dart';

void main() {
  group('AIService Risk Engine', () {
    late AIService aiService;

    setUp(() {
      aiService = AIService();
    });

    test('Initial risk level is low', () {
      expect(aiService.currentRiskLevel, RiskLevel.low);
    });

    test('Risk level enum mapping is valid', () {
      expect(RiskLevel.values.length, 3);
      expect(RiskLevel.values.contains(RiskLevel.low), isTrue);
      expect(RiskLevel.values.contains(RiskLevel.medium), isTrue);
      expect(RiskLevel.values.contains(RiskLevel.high), isTrue);
    });
  });
}
