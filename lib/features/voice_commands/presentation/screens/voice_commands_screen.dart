/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/features/voice_commands/data/voice_command_service.dart';
import 'package:guardian/features/voice_commands/presentation/widgets/command_list_item.dart';
import 'package:guardian/features/voice_commands/presentation/widgets/voice_recognition_button.dart';

class VoiceCommandsScreen extends StatefulWidget {
  const VoiceCommandsScreen({super.key});

  @override
  State<VoiceCommandsScreen> createState() => _VoiceCommandsScreenState();
}

class _VoiceCommandsScreenState extends State<VoiceCommandsScreen> {
  final VoiceCommandService _commandService = sl<VoiceCommandService>();

  VoiceRecognitionStatus _status = VoiceRecognitionStatus.notStarted;
  String _lastCommand = '';
  // We don't need this variable as we're showing the command status through UI
  // bool _commandSuccess = false;
  List<String> _exampleCommands = [];

  @override
  void initState() {
    super.initState();
    _setupVoiceCommandService();
    _loadExampleCommands();
  }

  @override
  void dispose() {
    _commandService.stopListening();
    super.dispose();
  }

  void _setupVoiceCommandService() {
    _commandService.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });

    _commandService.commandStream.listen((command) {
      setState(() {
        _lastCommand = command;
      });
    });
  }

  void _loadExampleCommands() {
    setState(() {
      _exampleCommands = _commandService.getExampleCommands();
    });
  }

  Future<void> _toggleListening() async {
    try {
      if (_commandService.isActive) {
        await _commandService.stopListening();
      } else {
        await _commandService.startListening();
      }
    } catch (e) {
      Logger.error('Failed to toggle voice recognition', e);
    }
  }

  Future<void> _simulateCommand(String command) async {
    try {
      final success = await _commandService.simulateVoiceCommand(command);

      // We don't need to track success separately as we update the UI directly
      setState(() {
        // Update UI state based on success if needed
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Command executed: $command'
                  : 'Failed to execute command: $command',
            ),
            backgroundColor: success ? AppColors.success : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to simulate command', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Voice Commands',
      ),
      body: Column(
        children: [
          // Voice recognition status
          Container(
            padding: const EdgeInsets.all(16),
            color: _getStatusColor().withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(),
                        style: AppTypography.heading4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lastCommand.isNotEmpty &&
                          _status == VoiceRecognitionStatus.recognized) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Command: $_lastCommand',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Voice recognition button
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Tap and hold to speak',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                VoiceRecognitionButton(
                  isListening: _commandService.isActive,
                  onPressed: _toggleListening,
                ),
                const SizedBox(height: 16),
                Text(
                  'Release when finished',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Example commands
          Expanded(
            child: _buildExampleCommands(),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCommands() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Example Commands',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _exampleCommands.length,
            itemBuilder: (context, index) {
              final command = _exampleCommands[index];

              return CommandListItem(
                command: command,
                onTap: () => _simulateCommand(command),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case VoiceRecognitionStatus.listening:
        return AppColors.primary;
      case VoiceRecognitionStatus.processing:
        return AppColors.info;
      case VoiceRecognitionStatus.recognized:
        return AppColors.success;
      case VoiceRecognitionStatus.notRecognized:
        return AppColors.warning;
      case VoiceRecognitionStatus.error:
        return AppColors.danger;
      case VoiceRecognitionStatus.notStarted:
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case VoiceRecognitionStatus.listening:
        return Icons.mic;
      case VoiceRecognitionStatus.processing:
        return Icons.hourglass_top;
      case VoiceRecognitionStatus.recognized:
        return Icons.check_circle;
      case VoiceRecognitionStatus.notRecognized:
        return Icons.error_outline;
      case VoiceRecognitionStatus.error:
        return Icons.error;
      case VoiceRecognitionStatus.notStarted:
      default:
        return Icons.mic_off;
    }
  }

  String _getStatusText() {
    switch (_status) {
      case VoiceRecognitionStatus.listening:
        return 'Listening...';
      case VoiceRecognitionStatus.processing:
        return 'Processing...';
      case VoiceRecognitionStatus.recognized:
        return 'Command Recognized';
      case VoiceRecognitionStatus.notRecognized:
        return 'Command Not Recognized';
      case VoiceRecognitionStatus.error:
        return 'Error Occurred';
      case VoiceRecognitionStatus.notStarted:
      default:
        return 'Voice Recognition Inactive';
    }
  }
}
