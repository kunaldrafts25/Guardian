/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/ai_assistant/data/models/ai_model.dart';
import 'package:intl/intl.dart';

/// A bubble widget for displaying chat messages
class ChatBubble extends StatelessWidget {
  /// The message to display
  final ChatMessage message;

  /// Callback when advice is tapped
  final VoidCallback? onAdviceTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.onAdviceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: message.isUserMessage
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!message.isUserMessage) _buildAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: message.isUserMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: message.isUserMessage
                      ? AppColors.primary
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: message.isUserMessage
                        ? const Radius.circular(16)
                        : const Radius.circular(0),
                    bottomRight: message.isUserMessage
                        ? const Radius.circular(0)
                        : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: AppTypography.bodyMedium.copyWith(
                    color: message.isUserMessage
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (message.containsAdvice && onAdviceTap != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAdviceTap,
                      child: Text(
                        'View Advice',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (message.isUserMessage) _buildAvatar(isUser: true),
      ],
    );
  }

  Widget _buildAvatar({bool isUser = false}) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.accent.withOpacity(0.2),
      child: Icon(
        isUser ? Icons.person : Icons.assistant,
        size: 16,
        color: isUser ? AppColors.primary : AppColors.accent,
      ),
    );
  }
}
