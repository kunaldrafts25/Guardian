/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/features/safety_tips/data/safety_tip_model.dart';
import 'package:guardian/features/community/presentation/widgets/safety_tip_card.dart';

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  List<SafetyTip> _safetyTips = [];
  List<SafetyTip> _filteredTips = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSafetyTips();
  }

  Future<void> _loadSafetyTips() async {
    // In a real app, this would fetch from Firestore
    // For now, we'll use mock data
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    setState(() {
      _safetyTips = mockSafetyTips;
      _filteredTips = mockSafetyTips;
      _isLoading = false;
    });
  }

  List<String> _getCategories() {
    final categories = _safetyTips.map((tip) => tip.category.displayName).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  void _filterTips(String categoryName) {
    setState(() {
      _selectedCategory = categoryName;
      if (categoryName == 'All') {
        _filteredTips = _safetyTips;
      } else {
        _filteredTips = _safetyTips.where((tip) => tip.category.displayName == categoryName).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.safetyTips),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category filter
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _getCategories().length,
                    itemBuilder: (context, index) {
                      final category = _getCategories()[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          onSelected: (selected) {
                            if (selected) {
                              _filterTips(category);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Safety tips list
                Expanded(
                  child: _filteredTips.isEmpty
                      ? const Center(
                          child: Text(
                            'No safety tips available for this category',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSafetyTips,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredTips.length,
                            itemBuilder: (context, index) {
                              return SafetyTipCard(
                                safetyTip: _filteredTips[index],
                                isDetailed: true,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// Mock data - using sample data from the safety_tips feature
final List<SafetyTip> mockSafetyTips = [
  SafetyTip(
    title: 'Stay Aware of Your Surroundings',
    description: 'Always be aware of your surroundings, especially when walking alone. Avoid using headphones or looking at your phone when walking in unfamiliar areas.',
    icon: Icons.visibility,
    color: AppColors.primary,
    category: SafetyTipCategory.awareness,
  ),
  SafetyTip(
    title: 'Share Your Location with Trusted Contacts',
    description: 'When going out, share your location with trusted friends or family members. Let them know your plans and when you expect to return.',
    icon: Icons.share_location,
    color: AppColors.secondary,
    category: SafetyTipCategory.travel,
  ),
  SafetyTip(
    title: 'Trust Your Instincts',
    description: 'If a situation or person makes you feel uncomfortable, trust your instincts and remove yourself from the situation. Your safety is the priority.',
    icon: Icons.psychology,
    color: AppColors.warning,
    category: SafetyTipCategory.awareness,
  ),
  SafetyTip(
    title: 'Use Well-Lit and Populated Routes',
    description: 'When walking at night, stick to well-lit and populated areas. Avoid shortcuts through isolated areas, even if they save time.',
    icon: Icons.lightbulb,
    color: AppColors.secondary,
    category: SafetyTipCategory.travel,
  ),
  SafetyTip(
    title: 'Secure Your Digital Accounts',
    description: 'Use strong, unique passwords for all your accounts and enable two-factor authentication when available to protect your personal information.',
    icon: Icons.security,
    color: AppColors.secondary,
    category: SafetyTipCategory.technology,
  ),
];