import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _localePrefKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _initLocale();
    return const Locale('en');
  }

  Future<void> _initLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_localePrefKey);
      if (savedCode != null && (savedCode == 'en' || savedCode == 'bn')) {
        state = Locale(savedCode);
      } else {
        final platformLocale = ui.PlatformDispatcher.instance.locale.languageCode;
        if (platformLocale == 'bn') {
          state = const Locale('bn');
        }
      }
    } catch (e) {
      debugPrint('[LocaleNotifier] Error loading saved locale: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (state.languageCode == newLocale.languageCode) return;
    state = newLocale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localePrefKey, newLocale.languageCode);
    } catch (e) {
      debugPrint('[LocaleNotifier] Error saving locale: $e');
    }
  }

  Future<void> toggleLocale() async {
    final next = state.languageCode == 'en' ? const Locale('bn') : const Locale('en');
    await setLocale(next);
  }
}

final localeNotifierProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

final localeProvider = localeNotifierProvider;
