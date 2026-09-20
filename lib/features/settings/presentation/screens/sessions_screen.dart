import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(authenticatedSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Signed-in devices')),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(authenticatedSessionsProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(authenticatedSessionsProvider.future),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.devices_other, size: 56, color: Colors.grey),
                    SizedBox(height: 16),
                    Center(child: Text('No active device sessions found.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _SessionTile(session: items[index]),
                ),
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final AuthenticatedSession session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSeen = session.lastSeenAt?.toLocal();
    final detail = lastSeen == null
        ? session.platform
        : '${session.platform} · Active ${_formatDate(lastSeen)}';
    return ListTile(
      leading: Icon(
        session.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android,
      ),
      title: Text(session.deviceLabel),
      subtitle: Text(session.isCurrent ? '$detail · This device' : detail),
      trailing: session.status != 'active'
          ? const Text('Revoked')
          : TextButton(
              onPressed: () => _confirmRevoke(context, ref),
              child: Text(session.isCurrent ? 'Sign out' : 'Revoke'),
            ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            session.isCurrent ? 'Sign out this device?' : 'Revoke device?'),
        content: Text(
          session.isCurrent
              ? 'You will need a new verification code to sign in again.'
              : 'This device will lose Guardian account access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(session.isCurrent ? 'Sign out' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(authServiceProvider).revokeSession(session.id);
      ref.invalidate(authenticatedSessionsProvider);
      if (context.mounted && !session.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device session revoked.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _formatDate(DateTime value) {
    final now = DateTime.now();
    if (now.difference(value).inDays == 0) {
      final minute = value.minute.toString().padLeft(2, '0');
      return 'today at ${value.hour}:$minute';
    }
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
