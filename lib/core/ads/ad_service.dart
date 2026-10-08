import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_unit_ids.dart';

/// Provider for accessing the singleton [AdService].
final adServiceProvider = Provider<AdService>((ref) => AdService.instance);

/// Manages Google AdMob banner, interstitial, and rewarded ad lifecycles.
///
/// Designed to be completely safe across all platforms:
/// - Fully no-ops on Flutter Web (`kIsWeb`) without plugin crashes.
/// - Gracefully falls back when offline so user features are never blocked.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Interstitial Ad state
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _transactionActionCounter = 0;
  DateTime? _lastInterstitialShownAt;

  // Configuration for frequency capping
  static const int interstitialInterval = 3; // Trigger every 3rd transaction
  static const Duration interstitialCooldown = Duration(seconds: 90);

  // Rewarded Ad state
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  /// Initializes the Google Mobile Ads SDK and pre-loads initial ads.
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[AdService] Skipping initialization on web platform.');
      return;
    }

    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Google Mobile Ads initialized successfully.');

      // Pre-cache ads for seamless display
      preloadInterstitialAd();
      preloadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] Error initializing MobileAds: $e');
    }
  }

  // ===========================================================================
  // INTERSTITIAL ADS
  // ===========================================================================

  /// Pre-loads an interstitial ad into memory.
  void preloadInterstitialAd() {
    if (kIsWeb || _isInterstitialLoading || _interstitialAd != null) return;

    _isInterstitialLoading = true;
    final adUnitId = AdUnitIds.interstitialAdUnitId;
    if (adUnitId.isEmpty) {
      _isInterstitialLoading = false;
      return;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('[AdService] Interstitial ad preloaded successfully.');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitialAd(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Interstitial failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial ad failed to load: $error');
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  /// Increments the transaction counter and displays an interstitial ad
  /// if the threshold (every 3rd save) and cooldown criteria are satisfied.
  void showInterstitialOnTransactionSave() {
    if (kIsWeb) return;

    _transactionActionCounter++;
    debugPrint('[AdService] Transaction action count: $_transactionActionCounter');

    if (_transactionActionCounter % interstitialInterval != 0) {
      return;
    }

    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < interstitialCooldown) {
      debugPrint('[AdService] Interstitial skipped due to active cooldown.');
      return;
    }

    if (_interstitialAd != null) {
      _lastInterstitialShownAt = now;
      _interstitialAd!.show();
    } else {
      preloadInterstitialAd();
    }
  }

  // ===========================================================================
  // REWARDED ADS
  // ===========================================================================

  /// Pre-loads a rewarded ad into memory.
  void preloadRewardedAd() {
    if (kIsWeb || _isRewardedLoading || _rewardedAd != null) return;

    _isRewardedLoading = true;
    final adUnitId = AdUnitIds.rewardedAdUnitId;
    if (adUnitId.isEmpty) {
      _isRewardedLoading = false;
      return;
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('[AdService] Rewarded ad preloaded successfully.');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isRewardedLoading = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad to unlock a feature.
  ///
  /// - On Web (`kIsWeb`): Immediately invokes [onUserEarnedReward].
  /// - If Ad is loaded: Plays video and invokes [onUserEarnedReward] when completed.
  /// - If Ad is not loaded (offline/error): Gracefully invokes [onUserEarnedReward]
  ///   so users are never blocked from accessing their documents.
  Future<void> showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
  }) async {
    if (kIsWeb) {
      onUserEarnedReward();
      onAdClosed?.call();
      return;
    }

    final currentAd = _rewardedAd;
    if (currentAd == null) {
      debugPrint('[AdService] Rewarded ad not ready, granting feature access as fallback.');
      preloadRewardedAd();
      onUserEarnedReward();
      onAdClosed?.call();
      return;
    }

    bool earned = false;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        preloadRewardedAd(); // Cache the next rewarded ad
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        preloadRewardedAd();
        // Fallback: don't penalize user for ad network failure
        if (!earned) {
          onUserEarnedReward();
        }
        onAdClosed?.call();
      },
    );

    await currentAd.show(
      onUserEarnedReward: (adWithoutView, reward) {
        earned = true;
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        onUserEarnedReward();
      },
    );
  }
}
