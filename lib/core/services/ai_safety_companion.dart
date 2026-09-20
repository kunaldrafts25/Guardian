import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/utils/logger.dart';

final aiCompanionProvider = Provider<AISafetyCompanion>(
    (ref) => AISafetyCompanion(AwsIncidentService.instance));

final aiCompanionStateProvider =
    StateNotifierProvider<AISafetyCompanionNotifier, AISafetyCompanionState>(
  (ref) => AISafetyCompanionNotifier(ref.read(aiCompanionProvider)),
);

enum AICompanionStatus { idle, loading, ready, generating, error, unavailable }

class AISafetyCompanionState {
  final AICompanionStatus status;
  final String? currentResponse;
  final List<ChatMessage> history;
  final String? error;

  const AISafetyCompanionState({
    this.status = AICompanionStatus.idle,
    this.currentResponse,
    this.history = const [],
    this.error,
  });

  AISafetyCompanionState copyWith({
    AICompanionStatus? status,
    String? currentResponse,
    List<ChatMessage>? history,
    String? error,
  }) {
    return AISafetyCompanionState(
      status: status ?? this.status,
      currentResponse: currentResponse ?? this.currentResponse,
      history: history ?? this.history,
      error: error,
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AISafetyCompanionNotifier extends StateNotifier<AISafetyCompanionState> {
  final AISafetyCompanion _companion;

  AISafetyCompanionNotifier(this._companion)
      : super(const AISafetyCompanionState());

  Future<void> initialize() async {
    state = state.copyWith(status: AICompanionStatus.loading);
    try {
      await _companion.initialize();
      state = state.copyWith(status: AICompanionStatus.ready);
    } catch (error, stackTrace) {
      Logger.error('AI companion initialization failed', error, stackTrace);
      state = state.copyWith(
        status: AICompanionStatus.unavailable,
        error: 'Safety assistant is unavailable.',
      );
    }
  }

  Future<void> ask(String question, {String? incidentId}) async {
    final userMessage = ChatMessage(
      text: question,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      status: AICompanionStatus.generating,
      history: [...state.history, userMessage],
      error: null,
    );
    try {
      final response = await _companion.ask(question, incidentId: incidentId);
      state = state.copyWith(
        status: AICompanionStatus.ready,
        currentResponse: response,
        history: [
          ...state.history,
          ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
        ],
      );
    } catch (error, stackTrace) {
      Logger.error('AI companion response failed', error, stackTrace);
      state = state.copyWith(
        status: AICompanionStatus.error,
        error:
            'Safety assistant is unavailable. Please use SOS or call emergency services.',
      );
    }
  }

  Future<String> draftIncidentReport(Map<String, dynamic> incident) =>
      _companion.draftIncidentReport(incident);

  void clearHistory() => state = state.copyWith(history: []);
}

class AISafetyCompanion {
  final AwsIncidentService _service;

  AISafetyCompanion(this._service);

  Future<void> initialize() async {
    if (_service.baseUrl.isEmpty) {
      throw StateError('AWS API endpoint is not configured');
    }
  }

  Future<String> ask(String question, {String? incidentId}) =>
      _service.askSafetyCompanion(question, incidentId: incidentId);

  Future<String> draftIncidentReport(Map<String, dynamic> incident) async {
    final type = incident['type'] ?? 'Incident';
    final description = incident['description'] ?? '';
    final location = incident['location'] ?? 'Location not specified';
    final time = incident['time'] ?? DateTime.now().toIso8601String();
    return 'INCIDENT REPORT\n\nType: $type\nDate/Time: $time\nLocation: $location\n\nDescription:\n$description';
  }
}
