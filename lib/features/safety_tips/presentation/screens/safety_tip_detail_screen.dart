/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/safety_tips/data/safety_tip_model.dart';

/// A screen to display the details of a safety tip
class SafetyTipDetailScreen extends StatelessWidget {
  /// The safety tip to display
  final SafetyTip tip;

  const SafetyTipDetailScreen({
    super.key,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tip.category.displayName),
        backgroundColor: tip.color,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tip.color,
                    tip.color.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tip.icon,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    tip.title,
                    style: AppTypography.heading1.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'Description',
                    style: AppTypography.heading4.copyWith(
                      color: tip.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tip.description,
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Additional information (mock data)
                  Text(
                    'Why This Matters',
                    style: AppTypography.heading4.copyWith(
                      color: tip.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getWhyThisMatters(tip.category),
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // How to practice
                  Text(
                    'How to Practice',
                    style: AppTypography.heading4.copyWith(
                      color: tip.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._getHowToPracticeSteps(tip.category).map((step) => _buildStep(step)),
                  const SizedBox(height: 24),

                  // Related tips
                  Text(
                    'Related Tips',
                    style: AppTypography.heading4.copyWith(
                      color: tip.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._getRelatedTips(tip.category).map((relatedTip) => _buildRelatedTip(relatedTip)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tip.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedTip(String relatedTip) {
    return Card(
      elevation: 0,
      color: tip.color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: tip.color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                relatedTip,
                style: AppTypography.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWhyThisMatters(SafetyTipCategory category) {
    switch (category) {
      case SafetyTipCategory.selfDefense:
        return 'Knowing basic self-defense techniques can boost your confidence and provide critical skills for emergency situations. Even simple techniques can create opportunities to escape dangerous situations.';
      case SafetyTipCategory.awareness:
        return 'Being aware of your surroundings is one of the most effective preventative safety measures. Many potential threats can be avoided entirely through heightened awareness and trusting your instincts.';
      case SafetyTipCategory.communication:
        return 'Clear communication with trusted contacts can be a lifeline in emergency situations. Establishing protocols beforehand ensures you can get help quickly when needed.';
      case SafetyTipCategory.travel:
        return 'Taking precautions while traveling reduces your vulnerability and ensures that help can reach you quickly if needed. Simple adjustments to your route or habits can significantly improve your safety.';
      case SafetyTipCategory.technology:
        return 'In today\'s digital world, technological safety is as important as physical safety. Securing your devices and accounts protects your personal information and prevents potential harassment or stalking.';
      case SafetyTipCategory.legal:
        return 'Understanding your legal rights empowers you to take appropriate action when faced with harassment or threats. Knowledge of the law can also deter potential harassers who rely on your uncertainty.';
      case SafetyTipCategory.mentalHealth:
        return 'Mental wellness is a crucial component of overall safety. Stress management techniques help you stay calm and make better decisions in challenging situations.';
    }
  }

  List<String> _getHowToPracticeSteps(SafetyTipCategory category) {
    switch (category) {
      case SafetyTipCategory.selfDefense:
        return [
          'Practice the stance in front of a mirror to ensure proper form.',
          'Incorporate balance exercises into your daily routine to improve stability.',
          'Consider taking a self-defense class to learn proper technique from professionals.',
          'Practice with a friend to get comfortable with the movements.',
          'Remember that the goal is to create an opportunity to escape, not to win a fight.',
        ];
      case SafetyTipCategory.awareness:
        return [
          'Regularly scan your environment as you walk, noting potential exit routes.',
          'Practice walking confidently even when you don\'t feel confident.',
          'Remove headphones or keep volume low enough to hear your surroundings.',
          'Notice details about people around you without staring.',
          'Trust your gut feeling—if something feels wrong, move to a safer location.',
        ];
      case SafetyTipCategory.communication:
        return [
          'Create a list of code words with different meanings for different situations.',
          'Practice using these code words in casual conversation so they sound natural.',
          'Ensure your emergency contacts know what actions to take when they hear each code word.',
          'Regularly check in with your safety network to maintain the connection.',
          'Test your emergency communication plan occasionally to ensure it works.',
        ];
      case SafetyTipCategory.travel:
        return [
          'Before traveling to a new area, research safe and unsafe zones.',
          'Test your location sharing app with friends to ensure it works properly.',
          'Plan routes that stick to well-lit, populated areas, especially at night.',
          'Practice using the SOS features on your phone so you can activate them quickly if needed.',
          'Inform trusted contacts about your travel plans, including expected arrival times.',
        ];
      case SafetyTipCategory.technology:
        return [
          'Conduct a security audit of your devices and accounts monthly.',
          'Use a password manager to create and store strong, unique passwords.',
          'Enable two-factor authentication on all important accounts.',
          'Regularly check privacy settings on social media platforms.',
          'Be cautious about the personal information you share online.',
        ];
      case SafetyTipCategory.legal:
        return [
          'Research local laws regarding harassment, assault, and self-defense.',
          'Save the contact information for legal aid services in your area.',
          'Document any incidents of harassment or threats with dates, times, and details.',
          'Learn about the process for obtaining restraining orders in your jurisdiction.',
          'Consider consulting with a lawyer to understand your specific rights and options.',
        ];
      case SafetyTipCategory.mentalHealth:
        return [
          'Practice deep breathing for 5 minutes daily to build the habit.',
          'Identify your personal stress triggers and develop specific coping strategies for each.',
          'Create a self-care routine that includes activities that help you feel calm and centered.',
          'Build a support network of friends, family, or professionals you can talk to when needed.',
          'Learn to recognize the physical signs of anxiety so you can address them early.',
        ];
    }
  }

  List<String> _getRelatedTips(SafetyTipCategory category) {
    switch (category) {
      case SafetyTipCategory.selfDefense:
        return [
          'Target vulnerable areas like eyes, nose, throat, and groin for maximum effect.',
          'Use everyday objects like keys or a pen as improvised weapons if necessary.',
          'The element of surprise can be your greatest advantage—act decisively.',
        ];
      case SafetyTipCategory.awareness:
        return [
          'Vary your routine to avoid predictability.',
          'Notice behavioral cues that may indicate someone is following you.',
          'Identify safe havens along your regular routes where you can seek help if needed.',
        ];
      case SafetyTipCategory.communication:
        return [
          'Create a check-in system with friends when going out or meeting someone new.',
          'Program emergency numbers for quick access on your phone.',
          'Learn how to make emergency calls on your phone even when it\'s locked.',
        ];
      case SafetyTipCategory.travel:
        return [
          'Consider using ride-sharing services that allow you to share your trip details with others.',
          'When using public transportation, sit near the driver or in cars with other passengers.',
          'Have your keys ready before reaching your door to minimize time spent vulnerable.',
        ];
      case SafetyTipCategory.technology:
        return [
          'Regularly check for unauthorized apps or accounts linked to your profiles.',
          'Use a VPN when connecting to public Wi-Fi networks.',
          'Be cautious about granting location access to apps that don\'t need it.',
        ];
      case SafetyTipCategory.legal:
        return [
          'Learn the difference between civil and criminal proceedings for harassment cases.',
          'Understand what constitutes evidence that can be used in legal proceedings.',
          'Know the reporting procedures for different types of harassment or threats.',
        ];
      case SafetyTipCategory.mentalHealth:
        return [
          'Practice grounding techniques to use during moments of high stress.',
          'Develop a personal mantra or affirmation that helps you feel strong and centered.',
          'Learn to recognize and challenge negative thought patterns that increase anxiety.',
        ];
    }
  }
}
