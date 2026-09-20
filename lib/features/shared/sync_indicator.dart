import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/sync/sync_service.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    Widget iconWidget;
    String tooltip;

    switch (status) {
      case SyncStatus.syncing:
        iconWidget = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        );
        tooltip = 'Syncing with Supabase...';
      case SyncStatus.offline:
        iconWidget = const Icon(
          Icons.cloud_off_outlined,
          size: 20,
          color: Color(0xFF78909C),
        );
        tooltip = 'Offline - changes will sync when connected';
      case SyncStatus.error:
        iconWidget = const Icon(
          Icons.cloud_sync_outlined,
          size: 20,
          color: AppColors.debtText,
        );
        tooltip = 'Sync error - tap to retry';
      case SyncStatus.guest:
        iconWidget = const Icon(
          Icons.cloud_queue_outlined,
          size: 20,
          color: Color(0xFF78909C),
        );
        tooltip = 'Guest mode - not synced to cloud';
      case SyncStatus.idle:
        iconWidget = const Icon(
          Icons.cloud_done_outlined,
          size: 20,
          color: AppColors.primary,
        );
        tooltip = 'All changes synced';
    }

    return IconButton(
      icon: iconWidget,
      tooltip: tooltip,
      onPressed: () {
        ref.read(syncServiceProvider).fullSync();
      },
    );
  }
}
