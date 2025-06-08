/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// A search bar widget for NGOs
class NGOSearchBar extends StatefulWidget {
  /// Callback when search is performed
  final Function(String) onSearch;

  const NGOSearchBar({
    super.key,
    required this.onSearch,
  });

  @override
  State<NGOSearchBar> createState() => _NGOSearchBarState();
}

class _NGOSearchBarState extends State<NGOSearchBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    widget.onSearch(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search organizations...',
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {});
          widget.onSearch(value);
        },
        onSubmitted: (_) => _performSearch(),
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
