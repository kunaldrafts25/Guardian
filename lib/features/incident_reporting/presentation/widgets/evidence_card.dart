/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/incident_reporting/data/models/incident_report_model.dart';
import 'package:intl/intl.dart';

/// A card widget for displaying evidence files
class EvidenceCard extends StatelessWidget {
  /// The evidence file to display
  final EvidenceFile evidence;

  /// Callback when the delete button is pressed
  final VoidCallback? onDelete;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  const EvidenceCard({
    super.key,
    required this.evidence,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getEvidenceTitle(),
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy - hh:mm a')
                          .format(evidence.timestamp),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (evidence.fileSize != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(evidence.fileSize!),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.danger,
                  onPressed: onDelete,
                  tooltip: 'Delete evidence',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final icon = _getEvidenceIcon();
    final color = _getEvidenceColor();

    if (evidence.type == EvidenceType.image && evidence.localPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Image.file(
            File(evidence.localPath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: color.withOpacity(0.1),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        color: color,
        size: 30,
      ),
    );
  }

  IconData _getEvidenceIcon() {
    switch (evidence.type) {
      case EvidenceType.audio:
        return Icons.audiotrack;
      case EvidenceType.video:
        return Icons.videocam;
      case EvidenceType.image:
        return Icons.photo;
    }
  }

  Color _getEvidenceColor() {
    switch (evidence.type) {
      case EvidenceType.audio:
        return AppColors.info;
      case EvidenceType.video:
        return AppColors.primary;
      case EvidenceType.image:
        return AppColors.success;
    }
  }

  String _getEvidenceTitle() {
    switch (evidence.type) {
      case EvidenceType.audio:
        return 'Audio Recording';
      case EvidenceType.video:
        return 'Video Recording';
      case EvidenceType.image:
        return 'Photo Evidence';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
