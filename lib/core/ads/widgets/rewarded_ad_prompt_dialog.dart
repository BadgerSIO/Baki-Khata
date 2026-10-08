import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../ad_service.dart';

/// Prompts the user to watch a short sponsored video in order to unlock a Pro feature
/// (such as exporting or printing an official PDF Statement) for free.
class RewardedAdPromptDialog extends StatelessWidget {
  final String titleEn;
  final String titleBn;
  final String descriptionEn;
  final String descriptionBn;
  final bool isBengali;
  final VoidCallback onRewardUnlocked;

  const RewardedAdPromptDialog({
    super.key,
    required this.titleEn,
    required this.titleBn,
    required this.descriptionEn,
    required this.descriptionBn,
    required this.isBengali,
    required this.onRewardUnlocked,
  });

  /// Static helper to show the dialog and automatically trigger the rewarded ad flow.
  static Future<void> show({
    required BuildContext context,
    required String titleEn,
    required String titleBn,
    required String descriptionEn,
    required String descriptionBn,
    required bool isBengali,
    required VoidCallback onRewardUnlocked,
  }) async {
    // On web, bypass ad requirement directly
    if (kIsWeb) {
      onRewardUnlocked();
      return;
    }

    return showDialog<void>(
      context: context,
      builder: (ctx) => RewardedAdPromptDialog(
        titleEn: titleEn,
        titleBn: titleBn,
        descriptionEn: descriptionEn,
        descriptionBn: descriptionBn,
        isBengali: isBengali,
        onRewardUnlocked: onRewardUnlocked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isBengali ? titleBn : titleEn;
    final description = isBengali ? descriptionBn : descriptionEn;
    final watchLabel = isBengali ? 'ভিডিও দেখে ডাউনলোড করুন' : 'Watch Video to Export';
    final cancelLabel = isBengali ? 'বাতিল' : 'Cancel';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(
        description,
        style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568), height: 1.4),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: Color(0xFF718096)),
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            AdService.instance.showRewardedAd(
              onUserEarnedReward: onRewardUnlocked,
            );
          },
          icon: const Icon(Icons.ondemand_video_rounded, size: 18),
          label: Text(watchLabel),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
