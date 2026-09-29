import 'dart:async';

class CloudIncidentBinding {
  final String ownerUserId;
  final String localAlertId;
  final String cloudIncidentId;

  const CloudIncidentBinding({
    required this.ownerUserId,
    required this.localAlertId,
    required this.cloudIncidentId,
  });
}

class CloudIncidentBindingService {
  CloudIncidentBindingService._();
  static final CloudIncidentBindingService instance =
      CloudIncidentBindingService._();

  final StreamController<CloudIncidentBinding> _controller =
      StreamController<CloudIncidentBinding>.broadcast();

  Stream<CloudIncidentBinding> get stream => _controller.stream;

  void publish(CloudIncidentBinding binding) {
    if (!_controller.isClosed) {
      _controller.add(binding);
    }
  }
}
