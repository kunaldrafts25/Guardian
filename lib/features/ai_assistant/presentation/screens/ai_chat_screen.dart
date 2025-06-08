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
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/ai_assistant/data/ai_repository.dart';
import 'package:guardian/features/ai_assistant/data/models/ai_model.dart';
import 'package:guardian/features/ai_assistant/presentation/widgets/advice_card.dart';
import 'package:guardian/features/ai_assistant/presentation/widgets/chat_bubble.dart';
import 'package:guardian/features/ai_assistant/presentation/widgets/chat_input.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIRepository _repository = sl<AIRepository>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  SafetyAdvice? _locationAdvice;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _generateLocationAdvice();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final messages = await _repository.getChatHistory();

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      Logger.error('Failed to load chat history', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateLocationAdvice() async {
    try {
      final advice = await _repository.generateLocationAdvice();

      if (advice != null) {
        setState(() {
          _locationAdvice = advice;
        });
      }
    } catch (e) {
      Logger.error('Failed to generate location advice', e);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Clear input field
      _messageController.clear();

      // Add user message to UI immediately
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: message,
        isUserMessage: true,
      );

      setState(() {
        _messages.add(userMessage);
      });

      // Scroll to bottom
      _scrollToBottom();

      // Get AI response
      final aiResponse = await _repository.sendMessage(message);

      if (aiResponse != null) {
        setState(() {
          _messages.add(aiResponse);
          _isSending = false;
        });

        // Scroll to bottom again
        _scrollToBottom();
      } else {
        throw Exception('Failed to get AI response');
      }
    } catch (e) {
      Logger.error('Failed to send message', e);

      setState(() {
        _isSending = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _viewAdvice(String adviceId) async {
    try {
      final advice = await _repository.getSafetyAdviceById(adviceId);

      if (advice != null && mounted) {
        // Mark advice as read
        await _repository.markAdviceAsRead(adviceId);

        // Show advice details
        _showAdviceDetails(advice);
      }
    } catch (e) {
      Logger.error('Failed to view advice', e);
    }
  }

  void _showAdviceDetails(SafetyAdvice advice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  advice.title,
                  style: AppTypography.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Safety Advice',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  advice.content,
                  style: AppTypography.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (advice.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: advice.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        labelStyle: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'This advice is generated by AI and should be used as a general guideline. Always use your best judgment in safety situations.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Guardian AI Assistant',
      ),
      body: Column(
        children: [
          // Location advice card (if available)
          if (_locationAdvice != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: AdviceCard(
                advice: _locationAdvice!,
                onTap: () => _showAdviceDetails(_locationAdvice!),
              ),
            ),

          // Chat messages
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _buildChatMessages(),
          ),

          // Input field
          ChatInput(
            controller: _messageController,
            onSend: _sendMessage,
            isLoading: _isSending,
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    if (_messages.isEmpty) {
      return _buildWelcomeMessage();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ChatBubble(
            message: message,
            onAdviceTap: message.adviceId != null
                ? () => _viewAdvice(message.adviceId!)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assistant,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Guardian AI Assistant',
              style: AppTypography.heading3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I\'m here to help you stay safe. Ask me anything about personal safety, using the app, or get advice for specific situations.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Try asking:',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildSuggestionChip('How can I stay safe at night?'),
            const SizedBox(height: 8),
            _buildSuggestionChip('What should I do if I feel unsafe?'),
            const SizedBox(height: 8),
            _buildSuggestionChip('Is this area safe?'),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          text,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
