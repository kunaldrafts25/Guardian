/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/features/community/data/incident_model.dart';
import 'package:guardian/features/safety_tips/data/safety_tip_model.dart';
import 'package:guardian/features/community/presentation/screens/report_incident_screen.dart';
import 'package:guardian/features/community/presentation/screens/safety_tips_screen.dart';
import 'package:guardian/features/community/presentation/widgets/incident_card.dart';
import 'package:guardian/features/community/presentation/widgets/safety_tip_card.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Incident> _incidents = [];
  List<SafetyTip> _safetyTips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // In a real app, this would fetch from Firestore
    // For now, we'll use mock data
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    setState(() {
      _incidents = mockIncidents;
      _safetyTips = mockSafetyTips;
      _isLoading = false;
    });
  }

  void _navigateToReportIncident() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportIncidentScreen(),
      ),
    );
  }

  void _navigateToSafetyTips() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SafetyTipsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.community),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Reported Incidents'),
            Tab(text: 'Safety Tips'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Incidents tab
                _buildIncidentsTab(),

                // Safety tips tab
                _buildSafetyTipsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tabController.index == 0
            ? _navigateToReportIncident
            : null,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIncidentsTab() {
    return _incidents.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No incidents reported yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Be the first to report an incident',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _navigateToReportIncident,
                  icon: const Icon(Icons.add),
                  label: const Text('Report Incident'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _incidents.length,
              itemBuilder: (context, index) {
                return IncidentCard(incident: _incidents[index]);
              },
            ),
          );
  }

  Widget _buildSafetyTipsTab() {
    return Column(
      children: [
        // View all safety tips button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safety Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _navigateToSafetyTips,
                child: const Text('View All'),
              ),
            ],
          ),
        ),

        // Safety tips list
        Expanded(
          child: _safetyTips.isEmpty
              ? const Center(
                  child: Text(
                    'No safety tips available',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _safetyTips.length,
                    itemBuilder: (context, index) {
                      return SafetyTipCard(safetyTip: _safetyTips[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
