/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/onboarding/data/onboarding_page_model.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingPageModel pageModel;

  const OnboardingPage({
    super.key,
    required this.pageModel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: pageModel.backgroundColor ?? Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image or Icon
          if (pageModel.icon != null) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                pageModel.icon,
                size: 60,
                color: AppColors.primary,
              ),
            ),
          ] else ...[
            Image.asset(
              pageModel.imagePath,
              height: 240,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ],
          const SizedBox(height: 40),

          // Title
          Text(
            pageModel.title,
            style: AppTypography.heading1.copyWith(
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            pageModel.description,
            style: AppTypography.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
