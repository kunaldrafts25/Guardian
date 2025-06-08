/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// An input widget for chat messages
class ChatInput extends StatelessWidget {
  /// Controller for the input field
  final TextEditingController controller;

  /// Callback when the send button is pressed
  final VoidCallback onSend;

  /// Whether the input is loading
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isLoading ? null : onSend,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
