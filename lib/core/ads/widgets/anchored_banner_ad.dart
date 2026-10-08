import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_unit_ids.dart';

/// An anchored banner ad widget that cleanly docks at the bottom of screens.
///
/// - Safely renders [SizedBox.shrink] on Web (`kIsWeb`) or when ads fail to load.
/// - Automatically handles banner sizing, ad lifecycle, and disposal.
class AnchoredBannerAd extends StatefulWidget {
  final AdSize adSize;

  const AnchoredBannerAd({
    super.key,
    this.adSize = AdSize.banner,
  });

  @override
  State<AnchoredBannerAd> createState() => _AnchoredBannerAdState();
}

class _AnchoredBannerAdState extends State<AnchoredBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (kIsWeb) return;

    final unitId = AdUnitIds.bannerAdUnitId;
    if (unitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AnchoredBannerAd] Failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final double adHeight = _bannerAd!.size.height.toDouble();
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: adHeight + 6,
        color: Colors.white,
        alignment: Alignment.center,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: adHeight,
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
