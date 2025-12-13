/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Safe Zones Screen - Manage safe locations
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/models/safe_zone_model.dart';
import 'package:guardian/core/providers/safe_zone_provider.dart';
import 'package:guardian/core/providers/location_provider.dart';
import 'package:guardian/features/safezone/presentation/screens/location_picker_screen.dart';

class SafeZonesScreen extends ConsumerWidget {
  const SafeZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeZoneState = ref.watch(safeZoneProvider);
    final zones = safeZoneState.zones;
    final isInSafeZone = safeZoneState.isInSafeZone;
    final currentZone = safeZoneState.currentZone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Zones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: isInSafeZone 
                ? AppColors.success.withOpacity(0.1) 
                : AppColors.warning.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  isInSafeZone ? Icons.shield : Icons.warning_amber,
                  color: isInSafeZone ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInSafeZone 
                            ? 'You are in a safe zone' 
                            : 'You are outside safe zones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isInSafeZone ? AppColors.success : AppColors.warning,
                        ),
                      ),
                      if (currentZone != null)
                        Text(
                          currentZone.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Zone count header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Safe Zones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${zones.length}/${SafeZoneState.maxZones}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Zones List
          Expanded(
            child: zones.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: zones.length,
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      return _buildZoneCard(context, ref, zone);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: safeZoneState.canAddMore
          ? FloatingActionButton.extended(
              onPressed: () => _showAddZoneDialog(context, ref),
              icon: const Icon(Icons.add_location),
              label: const Text('Add Zone'),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Safe Zones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add locations like home and work to get alerts when you leave',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, WidgetRef ref, SafeZone zone) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: zone.isActive 
              ? AppColors.success.withOpacity(0.2) 
              : Colors.grey.withOpacity(0.2),
          child: Icon(
            _getZoneIcon(zone.type),
            color: zone.isActive ? AppColors.success : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Text(zone.name),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${zone.radius.toInt()}m',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (zone.notifyOnExit) ...[
              Icon(Icons.notifications_active, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('Exit alerts', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
            ],
            if (zone.autoGuardianMode) ...[
              Icon(Icons.shield, size: 12, color: AppColors.guardian),
              const SizedBox(width: 4),
              Text('Auto Guardian', style: TextStyle(fontSize: 11, color: AppColors.guardian)),
            ],
          ],
        ),
        trailing: Switch(
          value: zone.isActive,
          onChanged: (value) {
            ref.read(safeZoneProvider.notifier).toggleZone(zone.id);
          },
          activeColor: AppColors.success,
        ),
        onTap: () => _showEditZoneDialog(context, ref, zone),
        onLongPress: () => _showDeleteConfirmation(context, ref, zone),
      ),
    );
  }

  IconData _getZoneIcon(SafeZoneType type) {
    switch (type) {
      case SafeZoneType.home:
        return Icons.home;
      case SafeZoneType.work:
        return Icons.work;
      case SafeZoneType.school:
        return Icons.school;
      case SafeZoneType.gym:
        return Icons.fitness_center;
      case SafeZoneType.custom:
        return Icons.place;
    }
  }

  void _showAddZoneDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    SafeZoneType type = SafeZoneType.custom;
    double radius = 200;
    bool notifyOnExit = true;
    bool autoGuardianMode = false;

    // Get current location as default (mutable)
    final locationState = ref.read(locationProvider);
    double lat = locationState.position?.latitude ?? 0;
    double lng = locationState.position?.longitude ?? 0;
    String? locationAddress;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Safe Zone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name',
                    hintText: 'e.g. Home, Office',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SafeZoneType>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: SafeZoneType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                  )).toList(),
                  onChanged: (value) => setState(() => type = value!),
                ),
                const SizedBox(height: 16),
                Text('Radius: ${radius.toInt()}m'),
                Slider(
                  value: radius,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${radius.toInt()}m',
                  onChanged: (value) => setState(() => radius = value),
                ),
                SwitchListTile(
                  title: const Text('Notify when leaving'),
                  value: notifyOnExit,
                  onChanged: (value) => setState(() => notifyOnExit = value),
                ),
                SwitchListTile(
                  title: const Text('Auto Guardian mode'),
                  subtitle: const Text('Enable when leaving this zone'),
                  value: autoGuardianMode,
                  onChanged: (value) => setState(() => autoGuardianMode = value),
                ),
                const SizedBox(height: 8),
                // Location selection
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lat != 0 
                        ? AppColors.success.withValues(alpha: 0.1) 
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: lat != 0 ? AppColors.success : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            lat != 0 ? Icons.location_on : Icons.location_off,
                            size: 16,
                            color: lat != 0 ? AppColors.success : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lat != 0 
                                  ? (locationAddress ?? 'Location selected')
                                  : 'No location selected',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: lat != 0 ? AppColors.success : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lat != 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600], fontFamily: 'monospace'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push<PickedLocation>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocationPickerScreen(
                                      title: 'Pick Zone Location',
                                    ),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    lat = result.latitude;
                                    lng = result.longitude;
                                    locationAddress = result.address;
                                  });
                                }
                              },
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text('Pick on Map'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final currentLoc = ref.read(locationProvider);
                                if (currentLoc.hasLocation) {
                                  setState(() {
                                    lat = currentLoc.position!.latitude;
                                    lng = currentLoc.position!.longitude;
                                    locationAddress = 'Current location';
                                  });
                                }
                              },
                              icon: const Icon(Icons.my_location, size: 16),
                              label: const Text('Current'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && lat != 0) {
                  ref.read(safeZoneProvider.notifier).addZone(
                    SafeZone(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      latitude: lat,
                      longitude: lng,
                      radius: radius,
                      type: type,
                      isActive: true,
                      notifyOnExit: notifyOnExit,
                      autoGuardianMode: autoGuardianMode,
                      createdAt: DateTime.now(),
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${nameController.text} added')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditZoneDialog(BuildContext context, WidgetRef ref, SafeZone zone) {
    final nameController = TextEditingController(text: zone.name);
    SafeZoneType type = zone.type;
    double radius = zone.radius;
    bool notifyOnExit = zone.notifyOnExit;
    bool autoGuardianMode = zone.autoGuardianMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Safe Zone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SafeZoneType>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: SafeZoneType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                  )).toList(),
                  onChanged: (value) => setState(() => type = value!),
                ),
                const SizedBox(height: 16),
                Text('Radius: ${radius.toInt()}m'),
                Slider(
                  value: radius,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${radius.toInt()}m',
                  onChanged: (value) => setState(() => radius = value),
                ),
                SwitchListTile(
                  title: const Text('Notify when leaving'),
                  value: notifyOnExit,
                  onChanged: (value) => setState(() => notifyOnExit = value),
                ),
                SwitchListTile(
                  title: const Text('Auto Guardian mode'),
                  subtitle: const Text('Enable when leaving this zone'),
                  value: autoGuardianMode,
                  onChanged: (value) => setState(() => autoGuardianMode = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref.read(safeZoneProvider.notifier).updateZone(
                    zone.id,
                    zone.copyWith(
                      name: nameController.text,
                      type: type,
                      radius: radius,
                      notifyOnExit: notifyOnExit,
                      autoGuardianMode: autoGuardianMode,
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zone updated')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, SafeZone zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Safe Zone?'),
        content: Text('Remove "${zone.name}" from your safe zones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(safeZoneProvider.notifier).removeZone(zone.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${zone.name} removed')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safe Zones'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safe zones are locations where you feel safe.\n'),
            Text('• Get alerts when you leave a zone'),
            Text('• Auto-enable Guardian mode outside zones'),
            Text('• Up to 10 zones allowed'),
            Text('\nLong-press a zone to delete it.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
