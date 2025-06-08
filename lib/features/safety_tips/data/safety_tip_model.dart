/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// A model class for safety tips
class SafetyTip {
  /// The title of the safety tip
  final String title;
  
  /// The description of the safety tip
  final String description;
  
  /// The icon to display with the safety tip
  final IconData icon;
  
  /// The color of the safety tip card
  final Color color;
  
  /// The category of the safety tip
  final SafetyTipCategory category;
  
  SafetyTip({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
  });
}

/// Categories for safety tips
enum SafetyTipCategory {
  selfDefense,
  awareness,
  communication,
  travel,
  technology,
  legal,
  mentalHealth,
}

/// Extension to get display name for safety tip category
extension SafetyTipCategoryExtension on SafetyTipCategory {
  String get displayName {
    switch (this) {
      case SafetyTipCategory.selfDefense:
        return 'Self Defense';
      case SafetyTipCategory.awareness:
        return 'Awareness';
      case SafetyTipCategory.communication:
        return 'Communication';
      case SafetyTipCategory.travel:
        return 'Travel Safety';
      case SafetyTipCategory.technology:
        return 'Tech Safety';
      case SafetyTipCategory.legal:
        return 'Legal Rights';
      case SafetyTipCategory.mentalHealth:
        return 'Mental Health';
    }
  }
  
  IconData get icon {
    switch (this) {
      case SafetyTipCategory.selfDefense:
        return Icons.fitness_center;
      case SafetyTipCategory.awareness:
        return Icons.visibility;
      case SafetyTipCategory.communication:
        return Icons.phone_in_talk;
      case SafetyTipCategory.travel:
        return Icons.directions_walk;
      case SafetyTipCategory.technology:
        return Icons.phone_android;
      case SafetyTipCategory.legal:
        return Icons.gavel;
      case SafetyTipCategory.mentalHealth:
        return Icons.favorite;
    }
  }
}

/// Sample safety tips data
List<SafetyTip> sampleSafetyTips = [
  SafetyTip(
    title: 'Walk with Confidence',
    description: 'Keep your head up, shoulders back, and maintain a steady pace. Projecting confidence can deter potential harassers.',
    icon: Icons.directions_walk,
    color: AppColors.primary,
    category: SafetyTipCategory.awareness,
  ),
  SafetyTip(
    title: 'Basic Self-Defense Stance',
    description: 'Stand with feet shoulder-width apart, knees slightly bent, hands up to protect your face. This balanced position allows you to move quickly if needed.',
    icon: Icons.fitness_center,
    color: AppColors.accent,
    category: SafetyTipCategory.selfDefense,
  ),
  SafetyTip(
    title: 'Share Your Location',
    description: 'When traveling alone, share your live location with trusted contacts. Let them know your expected arrival time.',
    icon: Icons.share_location,
    color: AppColors.secondary,
    category: SafetyTipCategory.travel,
  ),
  SafetyTip(
    title: 'Use Code Words',
    description: 'Establish code words or phrases with friends and family that signal you need help without alerting others around you.',
    icon: Icons.code,
    color: AppColors.warning,
    category: SafetyTipCategory.communication,
  ),
  SafetyTip(
    title: 'Secure Your Devices',
    description: 'Use strong passwords, enable two-factor authentication, and regularly update privacy settings on all your devices and accounts.',
    icon: Icons.security,
    color: AppColors.secondary,
    category: SafetyTipCategory.technology,
  ),
  SafetyTip(
    title: 'Know Your Rights',
    description: 'Familiarize yourself with local laws regarding harassment and assault. Knowledge empowers you to take appropriate action.',
    icon: Icons.gavel,
    color: AppColors.primary,
    category: SafetyTipCategory.legal,
  ),
  SafetyTip(
    title: 'Practice Deep Breathing',
    description: 'In stressful situations, take slow, deep breaths (4 counts in, 4 counts out) to calm your nervous system and think more clearly.',
    icon: Icons.favorite,
    color: AppColors.accent,
    category: SafetyTipCategory.mentalHealth,
  ),
  SafetyTip(
    title: 'Trust Your Instincts',
    description: 'If something feels wrong, it probably is. Don\'t ignore your intuition—it\'s your body\'s natural alarm system.',
    icon: Icons.psychology,
    color: AppColors.warning,
    category: SafetyTipCategory.awareness,
  ),
  SafetyTip(
    title: 'Use Well-Lit Routes',
    description: 'When walking at night, stick to well-lit, populated areas even if it means taking a slightly longer route.',
    icon: Icons.lightbulb,
    color: AppColors.secondary,
    category: SafetyTipCategory.travel,
  ),
  SafetyTip(
    title: 'Basic Strike: Palm Heel',
    description: 'The palm heel strike targets vulnerable areas like the nose or chin. Keep your hand open, fingers curled back, and strike with the base of your palm.',
    icon: Icons.back_hand,
    color: AppColors.accent,
    category: SafetyTipCategory.selfDefense,
  ),
];
