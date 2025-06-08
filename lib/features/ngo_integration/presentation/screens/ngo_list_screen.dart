/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:guardian/features/ngo_integration/data/ngo_repository.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/ngo_details_screen.dart';
import 'package:guardian/features/ngo_integration/presentation/widgets/ngo_card.dart';
import 'package:guardian/features/ngo_integration/presentation/widgets/ngo_search_bar.dart';
import 'package:guardian/features/ngo_integration/presentation/widgets/ngo_type_filter.dart';

class NGOListScreen extends StatefulWidget {
  const NGOListScreen({super.key});

  @override
  State<NGOListScreen> createState() => _NGOListScreenState();
}

class _NGOListScreenState extends State<NGOListScreen> {
  final NGORepository _repository = sl<NGORepository>();

  List<NGO> _ngos = [];
  List<NGO> _filteredNgos = [];
  bool _isLoading = true;
  NGOType? _selectedType;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNGOs();
  }

  Future<void> _loadNGOs() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final ngos = await _repository.getNGOs();

      setState(() {
        _ngos = ngos;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load NGOs', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredNgos = _ngos.where((ngo) {
        // Apply type filter
        if (_selectedType != null && ngo.type != _selectedType) {
          return false;
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return ngo.name.toLowerCase().contains(query) ||
              ngo.description.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
  }

  void _onTypeSelected(NGOType? type) {
    setState(() {
      _selectedType = type;
    });

    _applyFilters();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });

    _applyFilters();
  }

  void _navigateToNGODetails(NGO ngo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NGODetailsScreen(ngo: ngo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Safety Organizations',
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: NGOSearchBar(
              onSearch: _onSearch,
            ),
          ),

          // Type Filter
          NGOTypeFilter(
            selectedType: _selectedType,
            onTypeSelected: _onTypeSelected,
          ),

          // NGO List
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _buildNGOList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNGOList() {
    if (_filteredNgos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No organizations found',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search or filter',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNGOs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredNgos.length,
        itemBuilder: (context, index) {
          final ngo = _filteredNgos[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: NGOCard(
              ngo: ngo,
              onTap: () => _navigateToNGODetails(ngo),
            ),
          );
        },
      ),
    );
  }
}
