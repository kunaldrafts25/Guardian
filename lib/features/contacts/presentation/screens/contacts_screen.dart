/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Contacts Screen - Guardian Circle Management with CRUD
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/providers/contacts_provider.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);
    final contacts = contactsState.contacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Circle'),
        actions: [
          if (contacts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showInfoDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: AppColors.brandContainer.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppColors.brand),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Trusted Circle',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${contacts.length}/${ContactsState.maxContacts} contacts configured',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contacts List
          Expanded(
            child: contactsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : contactsState.errorMessage != null && contacts.isEmpty
                    ? _buildErrorState(context, contactsState.errorMessage!)
                    : contacts.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              final contact = contacts[index];
                              return _buildContactCard(
                                  context, ref, contact, index);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: contactsState.canAddMore
          ? FloatingActionButton.extended(
              onPressed: () => _showAddContactDialog(context, ref),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Contact'),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Emergency Contacts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add up to 5 trusted contacts who will be notified during emergencies',
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

  Widget _buildContactCard(BuildContext context, WidgetRef ref,
      EmergencyContact contact, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contact.isPrimary
              ? AppColors.brandContainer
              : AppColors.surfaceMuted,
          child: Text(
            contact.name[0].toUpperCase(),
            style: TextStyle(
              color: contact.isPrimary
                  ? AppColors.brand
                  : AppColors.secondaryAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(contact.name, overflow: TextOverflow.ellipsis)),
            if (contact.isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandContainer,
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(contact.phone),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'primary':
                try {
                  await ref
                      .read(contactsProvider.notifier)
                      .setPrimaryContact(index);
                } catch (error) {
                  if (context.mounted) _showMutationError(context, error);
                }
                break;
              case 'edit':
                _showEditContactDialog(context, ref, contact, index);
                break;
              case 'delete':
                _showDeleteConfirmation(context, ref, contact, index);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!contact.isPrimary)
              const PopupMenuItem(
                value: 'primary',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20),
                    SizedBox(width: 8),
                    Text('Set as Primary'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showEditContactDialog(context, ref, contact, index),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String relation = 'Family';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter contact name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: relation,
                  decoration: const InputDecoration(
                    labelText: 'Relation',
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: ['Family', 'Friend', 'Partner', 'Colleague', 'Other']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) => setState(() => relation = value!),
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
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  try {
                    await ref.read(contactsProvider.notifier).addContact(
                          EmergencyContact(
                            id: '',
                            name: nameController.text,
                            phone: phoneController.text,
                            relation: relation,
                          ),
                        );
                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(SnackBar(
                      content: Text(
                          '${nameController.text} added to Guardian Circle'),
                    ));
                  } catch (error) {
                    if (context.mounted) _showMutationError(context, error);
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditContactDialog(BuildContext context, WidgetRef ref,
      EmergencyContact contact, int index) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phone);
    String relation = contact.relation;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: relation,
                  decoration: const InputDecoration(
                    labelText: 'Relation',
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: ['Family', 'Friend', 'Partner', 'Colleague', 'Other']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) => setState(() => relation = value!),
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
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  try {
                    await ref.read(contactsProvider.notifier).updateContact(
                          index,
                          EmergencyContact(
                            id: contact.id,
                            name: nameController.text,
                            phone: phoneController.text,
                            relation: relation,
                            isPrimary: contact.isPrimary,
                          ),
                        );
                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Contact updated')),
                    );
                  } catch (error) {
                    if (context.mounted) _showMutationError(context, error);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref,
      EmergencyContact contact, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Contact?'),
        content: Text('Remove ${contact.name} from your Guardian Circle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              try {
                await ref.read(contactsProvider.notifier).removeContact(index);
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(content: Text('${contact.name} removed')),
                );
              } catch (error) {
                if (context.mounted) _showMutationError(context, error);
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showMutationError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact change failed: $error'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardian Circle'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Your Guardian Circle includes trusted contacts who will be notified during emergencies.\n'),
            Text('• Primary contact is notified first'),
            Text('• All contacts receive location'),
            Text('• Maximum 5 contacts allowed'),
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
