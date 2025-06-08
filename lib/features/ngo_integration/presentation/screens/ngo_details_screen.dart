/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/book_service_screen.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/donate_screen.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/volunteer_screen.dart';
import 'package:guardian/features/ngo_integration/presentation/widgets/service_card.dart';
import 'package:url_launcher/url_launcher.dart';

class NGODetailsScreen extends StatefulWidget {
  final NGO ngo;

  const NGODetailsScreen({
    super.key,
    required this.ngo,
  });

  @override
  State<NGODetailsScreen> createState() => _NGODetailsScreenState();
}

class _NGODetailsScreenState extends State<NGODetailsScreen> {
  // Removed unused field: final NGORepository _repository = sl<NGORepository>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.ngo.name,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),

            // Description
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: AppTypography.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ngo.description,
                    style: AppTypography.bodyLarge,
                  ),
                ],
              ),
            ),

            const Divider(),

            // Services
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Services',
                    style: AppTypography.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildServicesList(),
                ],
              ),
            ),

            const Divider(),

            // Contact Information
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Information',
                    style: AppTypography.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactInfo(),
                ],
              ),
            ),

            const Divider(),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get Involved',
                    style: AppTypography.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Image.network(
              widget.ngo.logoUrl,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.business,
                  size: 48,
                  color: AppColors.primary,
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            widget.ngo.name,
            style: AppTypography.heading3.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Type
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getNGOTypeLabel(widget.ngo.type),
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Verified Badge
          if (widget.ngo.isVerified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Verified Organization',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    if (widget.ngo.services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No services available',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.ngo.services.length,
      itemBuilder: (context, index) {
        final service = widget.ngo.services[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ServiceCard(
            service: service,
            onBook: () => _navigateToBookService(service),
          ),
        );
      },
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.ngo.phoneNumber != null) ...[
          _buildContactItem(
            icon: Icons.phone,
            label: 'Phone',
            value: widget.ngo.phoneNumber!,
            onTap: () => _launchUrl('tel:${widget.ngo.phoneNumber}'),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.ngo.email != null) ...[
          _buildContactItem(
            icon: Icons.email,
            label: 'Email',
            value: widget.ngo.email!,
            onTap: () => _launchUrl('mailto:${widget.ngo.email}'),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.ngo.websiteUrl != null) ...[
          _buildContactItem(
            icon: Icons.language,
            label: 'Website',
            value: widget.ngo.websiteUrl!,
            onTap: () => _launchUrl(widget.ngo.websiteUrl!),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.ngo.address != null) ...[
          _buildContactItem(
            icon: Icons.location_on,
            label: 'Address',
            value: _getFormattedAddress(),
            onTap: () => _launchMaps(),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.ngo.operatingHours != null) ...[
          _buildContactItem(
            icon: Icons.access_time,
            label: 'Operating Hours',
            value: widget.ngo.operatingHours!,
          ),
        ],
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Book Service
        if (widget.ngo.services.isNotEmpty)
          CustomButton(
            text: 'Book a Service',
            onPressed: () => _navigateToBookService(widget.ngo.services.first),
            type: ButtonType.primary,
            isFullWidth: true,
          ),

        const SizedBox(height: 16),

        // Donate
        if (widget.ngo.acceptsDonations)
          CustomButton(
            text: 'Make a Donation',
            onPressed: _navigateToDonate,
            type: ButtonType.outline,
            isFullWidth: true,
          ),

        const SizedBox(height: 16),

        // Volunteer
        if (widget.ngo.acceptsVolunteers)
          CustomButton(
            text: 'Volunteer',
            onPressed: _navigateToVolunteer,
            type: ButtonType.outline,
            isFullWidth: true,
          ),
      ],
    );
  }

  void _navigateToBookService(NGOService service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookServiceScreen(
          ngo: widget.ngo,
          service: service,
        ),
      ),
    );
  }

  void _navigateToDonate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DonateScreen(ngo: widget.ngo),
      ),
    );
  }

  void _navigateToVolunteer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerScreen(ngo: widget.ngo),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      Logger.error('Failed to launch URL', e);
    }
  }

  Future<void> _launchMaps() async {
    try {
      final address = _getFormattedAddress();
      final encodedAddress = Uri.encodeComponent(address);
      final url =
          'https://www.google.com/maps/search/?api=1&query=$encodedAddress';

      await _launchUrl(url);
    } catch (e) {
      Logger.error('Failed to launch maps', e);
    }
  }

  String _getFormattedAddress() {
    final parts = <String>[];

    if (widget.ngo.address != null) {
      parts.add(widget.ngo.address!);
    }

    if (widget.ngo.city != null) {
      parts.add(widget.ngo.city!);
    }

    if (widget.ngo.state != null) {
      parts.add(widget.ngo.state!);
    }

    if (widget.ngo.postalCode != null) {
      parts.add(widget.ngo.postalCode!);
    }

    if (widget.ngo.country != null) {
      parts.add(widget.ngo.country!);
    }

    return parts.join(', ');
  }

  String _getNGOTypeLabel(NGOType type) {
    switch (type) {
      case NGOType.womenSafety:
        return 'Women\'s Safety';
      case NGOType.crisisSupport:
        return 'Crisis Support';
      case NGOType.legalAid:
        return 'Legal Aid';
      case NGOType.mentalHealth:
        return 'Mental Health';
      case NGOType.communitySafety:
        return 'Community Safety';
      case NGOType.other:
        return 'Other';
    }
  }
}
