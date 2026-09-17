/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/core/services/maps_service.dart';
import 'package:guardian/core/utils/api_keys.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockResponse extends Mock implements http.Response {}

void main() {
  setUp(() {
    // Setup is empty as we're not using mocks in these tests
  });

  group('MapsService', () {
    test('defaultCameraPosition has correct values', () {
      expect(MapsService.defaultCameraPosition.target.latitude, 20.5937);
      expect(MapsService.defaultCameraPosition.target.longitude, 78.9629);
      expect(MapsService.defaultCameraPosition.zoom, 5);
    });

    test('decodePolyline correctly decodes encoded path', () {
      // This is a simple encoded polyline
      const String encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

      final List<LatLng> points = MapsService.decodePolyline(encoded);

      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 0.1));
      expect(points[0].longitude, closeTo(-120.2, 0.1));
      expect(points[1].latitude, closeTo(40.7, 0.1));
      expect(points[1].longitude, closeTo(-120.95, 0.1));
      expect(points[2].latitude, closeTo(43.252, 0.1));
      expect(points[2].longitude, closeTo(-126.453, 0.1));
    });

    test('getStaticMapUrl returns correct URL', () {
      // Arrange
      const LatLng center = LatLng(37.7749, -122.4194);
      const int zoom = 15;
      const int width = 600;
      const int height = 300;

      // Act
      final String url = MapsService.getStaticMapUrl(
        center: center,
        zoom: zoom,
        width: width,
        height: height,
      );

      // Assert
      expect(url, contains('https://maps.googleapis.com/maps/api/staticmap'));
      expect(url, contains('center=37.7749,-122.4194'));
      expect(url, contains('zoom=15'));
      expect(url, contains('size=600x300'));
      expect(url, contains('key=${ApiKeys.googleMaps}'));
    });

    test('calculateBounds returns correct LatLngBounds', () {
      // Arrange
      final List<LatLng> points = [
        const LatLng(37.7749, -122.4194), // San Francisco
        const LatLng(34.0522, -118.2437), // Los Angeles
        const LatLng(32.7157, -117.1611), // San Diego
      ];

      // Act
      final LatLngBounds bounds = MapsService.calculateBounds(points);

      // Assert
      expect(bounds.northeast.latitude, 37.7749);
      expect(bounds.northeast.longitude, -117.1611);
      expect(bounds.southwest.latitude, 32.7157);
      expect(bounds.southwest.longitude, -122.4194);
    });
  });
}
