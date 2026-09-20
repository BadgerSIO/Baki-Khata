import 'package:flutter/material.dart';
import '../../core/theme.dart';

enum MergeDecision {
  merge,
  discardLocal,
}

class MergeGuestDataDialog extends StatelessWidget {
  final int guestCustomerCount;
  final int guestTransactionCount;
  final int remoteCustomerCount;
  final String userEmail;

  const MergeGuestDataDialog({
    super.key,
    required this.guestCustomerCount,
    required this.guestTransactionCount,
    required this.remoteCustomerCount,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Merge Offline Data?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'We found existing data in this cloud account alongside offline records on this device.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF60706B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E5E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF60706B)),
                    const SizedBox(width: 6),
                    Text(
                      'Offline: $guestCustomerCount customer(s), $guestTransactionCount tx',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191C1B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined, size: 16, color: Color(0xFF60706B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cloud ($userEmail): $remoteCustomerCount customer(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191C1B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '• Merge Data: Combines offline records with your account, matching phone numbers to avoid duplicates.\n• Keep Cloud Only: Discards offline test data and loads your clean cloud account.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF78909C),
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, MergeDecision.discardLocal),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFCFD8DC)),
                  foregroundColor: AppColors.debtText,
                ),
                child: const Text(
                  'Keep Cloud Only',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, MergeDecision.merge),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Merge Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
