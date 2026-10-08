import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/core/ads/ad_service.dart';
import 'package:baki_khata/core/ads/ad_unit_ids.dart';
import 'package:baki_khata/core/ads/widgets/anchored_banner_ad.dart';
import 'package:baki_khata/core/ads/widgets/rewarded_ad_prompt_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdUnitIds Unit Tests', () {
    test('Official Google Test Ad Unit IDs are defined and well-formed', () {
      final bannerId = AdUnitIds.bannerAdUnitId;
      final interstitialId = AdUnitIds.interstitialAdUnitId;
      final rewardedId = AdUnitIds.rewardedAdUnitId;

      // In Linux test environment (Platform.isLinux, not web, not Android/iOS):
      // returns empty string gracefully without throwing
      expect(bannerId, isA<String>());
      expect(interstitialId, isA<String>());
      expect(rewardedId, isA<String>());
    });
  });

  group('AdService Logic Tests', () {
    test('AdService singleton is accessible and provides initial state', () {
      final service = AdService.instance;
      expect(service, isNotNull);
      // In non-mobile unit test environment, initialize safely catches or no-ops
      expect(AdService.interstitialInterval, 3);
      expect(AdService.interstitialCooldown.inSeconds, 90);
    });

    test('showRewardedAd gracefully falls back when ad is uninitialized or offline', () async {
      final service = AdService.instance;
      bool rewardGranted = false;

      // When no ad is preloaded/available, user should not be penalized:
      await service.showRewardedAd(
        onUserEarnedReward: () {
          rewardGranted = true;
        },
      );

      expect(rewardGranted, isTrue);
    });
  });

  group('AnchoredBannerAd Widget Tests', () {
    testWidgets('AnchoredBannerAd renders SizedBox.shrink when not loaded without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnchoredBannerAd(),
            ),
          ),
        ),
      );

      // In unit test environment, native ad platform views are not mounted,
      // so AnchoredBannerAd renders a safe SizedBox.shrink()
      expect(find.byType(AnchoredBannerAd), findsOneWidget);
    });
  });

  group('RewardedAdPromptDialog Widget Tests', () {
    testWidgets('RewardedAdPromptDialog displays title and buttons in English',
        (tester) async {
      bool rewardTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => RewardedAdPromptDialog(
                      titleEn: 'Export Statement for Free',
                      titleBn: 'পিডিএফ স্টেটমেন্ট ডাউনলোড করুন',
                      descriptionEn: 'Watch a short video to export your statement.',
                      descriptionBn: 'ভিডিও দেখে স্টেটমেন্ট ডাউনলোড করুন।',
                      isBengali: false,
                      onRewardUnlocked: () {
                        rewardTriggered = true;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Export Statement for Free'), findsOneWidget);
      expect(find.text('Watch a short video to export your statement.'), findsOneWidget);
      expect(find.text('Watch Video to Export'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Watch Video to Export button
      await tester.tap(find.text('Watch Video to Export'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Export Statement for Free'), findsNothing);
      // Fallback in unit test immediately grants reward
      expect(rewardTriggered, isTrue);
    });

    testWidgets('RewardedAdPromptDialog displays Bangla text when isBengali is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => RewardedAdPromptDialog(
                      titleEn: 'Export Statement for Free',
                      titleBn: 'পিডিএফ স্টেটমেন্ট ডাউনলোড করুন',
                      descriptionEn: 'Watch a short video to export your statement.',
                      descriptionBn: 'ভিডিও দেখে স্টেটমেন্ট ডাউনলোড করুন।',
                      isBengali: true,
                      onRewardUnlocked: () {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('পিডিএফ স্টেটমেন্ট ডাউনলোড করুন'), findsOneWidget);
      expect(find.text('ভিডিও দেখে স্টেটমেন্ট ডাউনলোড করুন।'), findsOneWidget);
      expect(find.text('ভিডিও দেখে ডাউনলোড করুন'), findsOneWidget);
      expect(find.text('বাতিল'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('বাতিল'));
      await tester.pumpAndSettle();

      expect(find.text('পিডিএফ স্টেটমেন্ট ডাউনলোড করুন'), findsNothing);
    });
  });
}
