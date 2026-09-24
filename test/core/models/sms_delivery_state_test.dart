import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/models/sms_delivery_state.dart';

void main() {
  group('SmsDeliveryState Semantics (P0-06)', () {
    test('composerOpened is NOT considered local OS accepted and must not suppress cloud fallback', () {
      const state = SmsDeliveryState.composerOpened;

      // Invariant: Opening the iOS SMS composer is NEVER a confirmed dispatch
      expect(state.isLocalOsAccepted, isFalse);
      expect(state.isAcceptedForDispatch, isFalse);
      expect(state.isDeliveredToHandset, isFalse);
      expect(state.serialized, 'COMPOSER_OPENED');
    });

    test('osAccepted is proven only by native SmsManager acceptance', () {
      const state = SmsDeliveryState.osAccepted;

      expect(state.isLocalOsAccepted, isTrue);
      expect(state.isAcceptedForDispatch, isTrue);
      // Handset delivery requires carrier receipt; OS acceptance is not handset delivery
      expect(state.isDeliveredToHandset, isFalse);
      expect(state.serialized, 'OS_ACCEPTED');
    });

    test('providerAccepted represents upstream cloud SNS publish without claiming handset delivery', () {
      const state = SmsDeliveryState.providerAccepted;

      expect(state.isLocalOsAccepted, isFalse);
      expect(state.isAcceptedForDispatch, isTrue);
      // Invariant: Cloud provider acceptance is NOT handset delivery
      expect(state.isDeliveredToHandset, isFalse);
      expect(state.serialized, 'PROVIDER_ACCEPTED');
    });

    test('delivered is the only state that confirms handset delivery', () {
      const state = SmsDeliveryState.delivered;

      expect(state.isAcceptedForDispatch, isTrue);
      expect(state.isDeliveredToHandset, isTrue);
    });

    test('parsing from string handles various cases safely', () {
      expect(SmsDeliveryState.fromString('OS_ACCEPTED'), SmsDeliveryState.osAccepted);
      expect(SmsDeliveryState.fromString('COMPOSER_OPENED'), SmsDeliveryState.composerOpened);
      expect(SmsDeliveryState.fromString('provider-accepted'), SmsDeliveryState.providerAccepted);
      expect(SmsDeliveryState.fromString('unknown_value'), SmsDeliveryState.unknown);
      expect(SmsDeliveryState.fromString(null), SmsDeliveryState.unknown);
    });
  });
}
