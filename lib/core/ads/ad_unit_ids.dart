import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized registry of Google AdMob Unit IDs.
///
/// Defaults to Google's official, publicly documented Test Ad Unit IDs:
/// https://developers.google.com/admob/android/test-ads
class AdUnitIds {
  AdUnitIds._();

  // --- Official Google Test Ad Unit IDs ---
  static const String _androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';

  static const String _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';

  static const String _androidRewardedTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTest = 'ca-app-pub-3940256099942544/1712485313';

  /// Returns the appropriate Banner Ad Unit ID based on platform.
  /// Returns empty string on Flutter Web.
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return _androidBannerTest;
    if (Platform.isIOS) return _iosBannerTest;
    return '';
  }

  /// Returns the appropriate Interstitial Ad Unit ID based on platform.
  /// Returns empty string on Flutter Web.
  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return _androidInterstitialTest;
    if (Platform.isIOS) return _iosInterstitialTest;
    return '';
  }

  /// Returns the appropriate Rewarded Ad Unit ID based on platform.
  /// Returns empty string on Flutter Web.
  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return _androidRewardedTest;
    if (Platform.isIOS) return _iosRewardedTest;
    return '';
  }
}
