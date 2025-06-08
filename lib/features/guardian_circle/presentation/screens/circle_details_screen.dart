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
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';
import 'package:guardian/features/guardian_circle/presentation/screens/add_member_screen.dart';
import 'package:guardian/features/guardian_circle/presentation/widgets/member_card.dart';

class CircleDetailsScreen extends StatefulWidget {
  final GuardianCircle circle;

  const CircleDetailsScreen({
    super.key,
    required this.circle,
  });

  @override
  State<CircleDetailsScreen> createState() => _CircleDetailsScreenState();
}

class _CircleDetailsScreenState extends State<CircleDetailsScreen> {
  final GuardianCircleRepository _repository = sl<GuardianCircleRepository>();

  late GuardianCircle _circle;
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _circle = widget.circle;
  }

  Future<void> _refreshCircle() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final circle = await _repository.getGuardianCircle(_circle.id);

      if (circle != null) {
        setState(() {
          _circle = circle;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to refresh circle', e);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh circle details'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddMember() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemberScreen(circleId: _circle.id),
      ),
    );

    if (result == true) {
      await _refreshCircle();
    }
  }

  Future<void> _removeMember(GuardianCircleMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove ${member.name} from this circle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _repository.removeMemberFromCircle(
        circleId: _circle.id,
        memberId: member.id,
      );

      if (!success) {
        throw Exception('Failed to remove member');
      }

      await _refreshCircle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} removed from circle'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to remove member', e);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteCircle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Circle'),
        content: const Text(
            'Are you sure you want to delete this circle? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      setState(() {
        _isDeleting = true;
      });

      final success = await _repository.deleteGuardianCircle(_circle.id);

      if (!success) {
        throw Exception('Failed to delete circle');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Failed to delete circle', e);

      setState(() {
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete circle: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _circle.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isDeleting ? null : _deleteCircle,
            tooltip: 'Delete Circle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMember,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circle Info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _circle.name,
                style: AppTypography.heading3,
              ),
              if (_circle.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  _circle.description!,
                  style: AppTypography.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${_circle.members.length} members',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (_circle.isDefault) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Default Circle',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const Divider(),

        // Members List
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Members',
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Expanded(
          child: _circle.members.isEmpty
              ? _buildEmptyMembers()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _circle.members.length,
                  itemBuilder: (context, index) {
                    final member = _circle.members[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MemberCard(
                        member: member,
                        onRemove: member.role != GuardianMemberRole.admin
                            ? () => _removeMember(member)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyMembers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Members',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 8),
          Text(
            'Add trusted contacts to your guardian circle',
            style: AppTypography.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddMember,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Member'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
