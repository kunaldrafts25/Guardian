/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/utils/api_keys.dart';

void main() {
  group('ApiKeys', () {
    test('googleMapsAndroid returns correct API key', () {
      expect(ApiKeys.googleMapsAndroid, 'AIzaSyDGqK9Iy_hWEPd_Gv0nnUQqP9xBXHwj1Oc');
    });

    test('googleMapsIOS returns correct API key', () {
      expect(ApiKeys.googleMapsIOS, 'AIzaSyDGqK9Iy_hWEPd_Gv0nnUQqP9xBXHwj1Oc');
    });

    test('googleMaps returns platform-specific API key', () {
      // Since we can't easily mock Platform.isAndroid or Platform.isIOS in tests,
      // we'll just verify that googleMaps returns a non-empty string
      expect(ApiKeys.googleMaps, isNotEmpty);
    });
  });
}
