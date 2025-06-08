/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/safety_tips/data/safety_tip_model.dart';
import 'package:guardian/features/safety_tips/presentation/screens/safety_tip_detail_screen.dart';
import 'package:guardian/features/safety_tips/presentation/widgets/safety_tip_card.dart';

/// A screen to display a list of safety tips
class SafetyTipsListScreen extends StatefulWidget {
  const SafetyTipsListScreen({super.key});

  @override
  State<SafetyTipsListScreen> createState() => _SafetyTipsListScreenState();
}

class _SafetyTipsListScreenState extends State<SafetyTipsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<SafetyTip> _tips = sampleSafetyTips;
  SafetyTipCategory? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SafetyTipCategory.values.length + 1, // +1 for "All" tab
      vsync: this,
    );
    _tabController.addListener(_handleTabSelection);
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == 0) {
          _selectedCategory = null; // "All" category
        } else {
          _selectedCategory = SafetyTipCategory.values[_tabController.index - 1];
        }
      });
    }
  }
  
  List<SafetyTip> get _filteredTips {
    if (_selectedCategory == null) {
      return _tips;
    }
    return _tips.where((tip) => tip.category == _selectedCategory).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Tips'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            const Tab(text: 'All'),
            ...SafetyTipCategory.values.map((category) => Tab(
              text: category.displayName,
            )),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _filteredTips.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTips.length,
                    itemBuilder: (context, index) {
                      final tip = _filteredTips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SafetyTipCard(
                          tip: tip,
                          onTap: () => _showTipDetails(tip),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tips available',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new safety tips',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showTipDetails(SafetyTip tip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SafetyTipDetailScreen(tip: tip),
      ),
    );
  }
}
