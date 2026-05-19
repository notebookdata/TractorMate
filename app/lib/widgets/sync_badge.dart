import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    IconData icon;
    Color color;
    String tooltip;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = AppTheme.paid;
        tooltip = 'Synced';
        break;
      case SyncStatus.syncing:
        icon = Icons.cloud_sync;
        color = Colors.blue;
        tooltip = 'Syncing...';
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload;
        color = AppTheme.partial;
        tooltip = 'Sync pending';
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = AppTheme.danger;
        tooltip = 'Sync error';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 24),
    );
  }
}
