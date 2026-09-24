/// Explicit SMS delivery and dispatch evidence states.
/// Only states actually proven by the local platform or upstream provider are used.
enum SmsDeliveryState {
  notAttempted,
  composerOpened,
  submissionRequested,
  osAccepted,
  providerAccepted,
  sent,
  delivered,
  failed,
  unknown;

  static SmsDeliveryState fromString(String? val) {
    if (val == null) return SmsDeliveryState.unknown;
    final lower = val.toLowerCase().replaceAll('-', '_');
    return switch (lower) {
      'not_attempted' => SmsDeliveryState.notAttempted,
      'composer_opened' => SmsDeliveryState.composerOpened,
      'submission_requested' => SmsDeliveryState.submissionRequested,
      'os_accepted' => SmsDeliveryState.osAccepted,
      'provider_accepted' => SmsDeliveryState.providerAccepted,
      'sent' => SmsDeliveryState.sent,
      'delivered' => SmsDeliveryState.delivered,
      'failed' => SmsDeliveryState.failed,
      _ => SmsDeliveryState.unknown,
    };
  }

  String get serialized => switch (this) {
        SmsDeliveryState.notAttempted => 'NOT_ATTEMPTED',
        SmsDeliveryState.composerOpened => 'COMPOSER_OPENED',
        SmsDeliveryState.submissionRequested => 'SUBMISSION_REQUESTED',
        SmsDeliveryState.osAccepted => 'OS_ACCEPTED',
        SmsDeliveryState.providerAccepted => 'PROVIDER_ACCEPTED',
        SmsDeliveryState.sent => 'SENT',
        SmsDeliveryState.delivered => 'DELIVERED',
        SmsDeliveryState.failed => 'FAILED',
        SmsDeliveryState.unknown => 'UNKNOWN',
      };

  /// Invariant: Opening the iOS SMS composer is NEVER a confirmed dispatch or delivery,
  /// and must NEVER suppress cloud fallback.
  bool get isLocalOsAccepted => this == SmsDeliveryState.osAccepted;

  /// True if the carrier/OS or cloud provider actually accepted the message for dispatch.
  bool get isAcceptedForDispatch =>
      this == SmsDeliveryState.osAccepted ||
      this == SmsDeliveryState.providerAccepted ||
      this == SmsDeliveryState.sent ||
      this == SmsDeliveryState.delivered;

  /// Handset delivery is only confirmed when carrier delivery receipt is received.
  bool get isDeliveredToHandset => this == SmsDeliveryState.delivered;
}

class SmsDispatchResult {
  final SmsDeliveryState state;
  final String? messageId;
  final String? error;
  final String? note;

  const SmsDispatchResult({
    required this.state,
    this.messageId,
    this.error,
    this.note,
  });
}
