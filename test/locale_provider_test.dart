import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baki_khata/core/locale_provider.dart';
import 'package:baki_khata/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleNotifier', () {
    test('Defaults to en when no saved preference exists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialLocale = container.read(localeNotifierProvider);
      expect(initialLocale.languageCode, 'en');
    });

    test('Initializes with saved locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'bn'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger read & allow async init to settle
      container.read(localeNotifierProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loadedLocale = container.read(localeNotifierProvider);
      expect(loadedLocale.languageCode, 'bn');
    });

    test('setLocale switches locale and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localeNotifierProvider.notifier);
      await notifier.setLocale(const Locale('bn'));

      expect(container.read(localeNotifierProvider).languageCode, 'bn');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'bn');

      // Switch back to English
      await notifier.setLocale(const Locale('en'));
      expect(container.read(localeNotifierProvider).languageCode, 'en');
      expect(prefs.getString('app_locale'), 'en');
    });

    test('toggleLocale switches back and forth between en and bn', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localeNotifierProvider.notifier);
      await notifier.toggleLocale();
      expect(container.read(localeNotifierProvider).languageCode, 'bn');

      await notifier.toggleLocale();
      expect(container.read(localeNotifierProvider).languageCode, 'en');
    });

    testWidgets('Widget tree reactively updates UI text when localeNotifierProvider changes', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(localeNotifierProvider);
              return MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx);
                      return Column(
                        children: [
                          Text(l10n?.giveCredit ?? ''),
                          Text(l10n?.totalDue ?? ''),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(localeNotifierProvider.notifier).setLocale(const Locale('bn'));
                            },
                            child: const Text('Change to Bangla'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially in English
      expect(find.text('Give Credit'), findsOneWidget);
      expect(find.text('Total Due'), findsOneWidget);
      expect(find.text('বাকি দিন'), findsNothing);
      expect(find.text('মোট বাকি'), findsNothing);

      // Tap button to switch to Bangla
      await tester.tap(find.text('Change to Bangla'));
      await tester.pumpAndSettle();

      // Now dynamically translated to natural Bangla
      expect(find.text('বাকি দিন'), findsOneWidget);
      expect(find.text('মোট বাকি'), findsOneWidget);
      expect(find.text('Give Credit'), findsNothing);
      expect(find.text('Total Due'), findsNothing);
    });
  });
}
