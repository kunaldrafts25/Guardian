/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// A search bar widget for the store
class StoreSearchBar extends StatefulWidget {
  /// Callback when search is performed
  final Function(String) onSearch;

  const StoreSearchBar({
    super.key,
    required this.onSearch,
  });

  @override
  State<StoreSearchBar> createState() => _StoreSearchBarState();
}

class _StoreSearchBarState extends State<StoreSearchBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _showClearButton = _searchController.text.isNotEmpty;
    });

    widget.onSearch(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
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
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search safety devices...',
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _showClearButton
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: Colors.white,
        ),
        onSubmitted: widget.onSearch,
      ),
    );
  }
}
