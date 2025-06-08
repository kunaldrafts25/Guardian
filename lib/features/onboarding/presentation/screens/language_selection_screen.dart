/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/services/language_service.dart';
import 'package:guardian/core/utils/page_transitions.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/auth/presentation/screens/login_screen.dart';
import 'package:provider/provider.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'en'; // Default to English

  @override
  void initState() {
    super.initState();
    // Get current language from service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageService = Provider.of<LanguageService>(context, listen: false);
      setState(() {
        _selectedLanguage = languageService.currentLanguageCode;
      });
    });
  }

  void _selectLanguage(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  Future<void> _continueToLogin() async {
    // Save selected language
    final languageService = Provider.of<LanguageService>(context, listen: false);
    await languageService.setLanguage(_selectedLanguage);

    if (!mounted) return;

    // Navigate to login screen
    Navigator.of(context).pushReplacement(
      PageTransitions.fadeSlide(
        page: const LoginScreen(),
        direction: SlideDirection.fromRight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              Text(
                'Choose Your Language',
                style: AppTypography.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select your preferred language for the app',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // Language options
              _buildLanguageOption('en', 'English', 'English'),
              const SizedBox(height: 16),
              _buildLanguageOption('hi', 'हिंदी', 'Hindi'),
              const SizedBox(height: 16),
              _buildLanguageOption('mr', 'मराठी', 'Marathi'),
              
              const Spacer(),

              // Continue button
              CustomButton(
                text: 'Continue',
                onPressed: _continueToLogin,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String code, String name, String englishName) {
    final isSelected = _selectedLanguage == code;
    
    return InkWell(
      onTap: () => _selectLanguage(code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Language name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  if (name != englishName)
                    Text(
                      englishName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
