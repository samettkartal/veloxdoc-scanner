import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  // Test ID'ler
  final String _androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _androidBannerId : _iosBannerId;
    }
    // Gerçek ID'ler buraya eklenecek, şimdilik test ID dönüyoruz
    return Platform.isAndroid ? _androidBannerId : _iosBannerId;
  }

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    
    // Add Test Device ID (from User Logs)
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: ["03AAB1D1182E7AD39EB1FABE4277682D"]),
    );
  }

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  final String _androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  final String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  String get interstitialAdUnitId {
     if (kDebugMode) {
      return Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;
    }
    return Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;
  }

  void loadInterstitialAd() {
    debugPrint("AdService: Loading Interstitial Ad...");
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("AdService: Interstitial Ad LOADED!");
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint("AdService: Interstitial Ad Dismissed. Disposing and reloading.");
              ad.dispose();
              loadInterstitialAd(); // Reload for next time
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("AdService: Failed to show Interstitial Ad: $error");
              ad.dispose();
              loadInterstitialAd();
            },
            onAdShowedFullScreenContent: (ad) {
               debugPrint("AdService: Interstitial Ad Showing!");
            }
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: InterstitialAd failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void showInterstitialAd() {
    debugPrint("AdService: Attempting to show Interstitial Ad. Ready? $_isInterstitialAdReady");
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
      _isInterstitialAdReady = false;
      _interstitialAd = null;
    } else {
      debugPrint('AdService: Interstitial ad not ready yet. Reloading...');
      loadInterstitialAd(); // Try loading again if it wasn't ready
    }
  }

  BannerAd createBannerAd({required Function(Ad) onAdLoaded, required Function(Ad, LoadAdError) onAdFailedToLoad}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAdReady = true;
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    )..load();
  }
}
