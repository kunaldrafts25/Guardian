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

/// A carousel widget to display safety tips
class SafetyTipsCarousel extends StatefulWidget {
  /// The list of safety tips to display
  final List<SafetyTip> tips;
  
  /// The title of the carousel
  final String title;
  
  /// Whether to show the "See All" button
  final bool showSeeAll;
  
  /// Callback when the "See All" button is tapped
  final VoidCallback? onSeeAllTap;
  
  const SafetyTipsCarousel({
    super.key,
    required this.tips,
    this.title = 'Safety Tips',
    this.showSeeAll = true,
    this.onSeeAllTap,
  });

  @override
  State<SafetyTipsCarousel> createState() => _SafetyTipsCarouselState();
}

class _SafetyTipsCarouselState extends State<SafetyTipsCarousel> {
  final PageController _pageController = PageController(
    viewportFraction: 0.9,
    initialPage: 0,
  );
  
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }
  
  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }
  
  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: AppTypography.heading3,
              ),
              if (widget.showSeeAll)
                TextButton(
                  onPressed: widget.onSeeAllTap,
                  child: Text(
                    'See All',
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Carousel
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.tips.length,
            itemBuilder: (context, index) {
              final tip = widget.tips[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SafetyTipCard(
                  tip: tip,
                  onTap: () => _showTipDetails(tip),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Page indicator
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              widget.tips.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primary
                      : AppColors.secondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
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
