import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/current_user_service.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'data/local/local_database.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/sync/sync_service.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/home_screen.dart';
import 'features/dashboard/home_user_header.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shared/quick_actions_fab.dart';
import 'features/shared/sync_indicator.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  try {
    return supabase.auth.onAuthStateChange;
  } catch (_) {
    return const Stream.empty();
  }
});

final currentTabProvider = StateProvider<int>((ref) => 0);

/// Checks whether any local settings row exists to decide between Onboarding and Main app.
final hasLocalSettingsProvider = FutureProvider<bool>((ref) async {
  return await LocalDatabase.instance.hasAnySettings();
});

/// Tracks whether the initial sync has completed for the current authenticated session.
final initialSyncCompletedProvider = StateProvider<bool>((ref) => false);

/// True when the effective user is still the guest sentinel AND has at least one
/// customer or transaction — meaning there is local data worth protecting.
/// Collapses to false the moment the user signs in.
final guestNeedsBackupProvider = Provider<bool>((ref) {
  // currentUserIdProvider is a StreamProvider — treat loading/error as guest.
  final userId = ref.watch(currentUserIdProvider).value ?? CurrentUserService.guestSentinel;
  if (userId != CurrentUserService.guestSentinel) return false;

  final customers = ref.watch(customersStreamProvider).value ?? [];
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  return customers.isNotEmpty || transactions.isNotEmpty;
});

class BakiKhataApp extends ConsumerWidget {
  const BakiKhataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSettingsAsync = ref.watch(hasLocalSettingsProvider);

    return MaterialApp(
      title: 'Baki Khata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: (settings) {
        // Gracefully handle deep links / OAuth callback query strings e.g. "/?code=..."
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => hasSettingsAsync.when(
            data: (hasSettings) {
              if (!hasSettings) {
                return const OnboardingScreen();
              }
              return const MainNavigationScaffold();
            },
            loading: () => const Scaffold(
              backgroundColor: Color(0xFFF7FAF8),
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => const OnboardingScreen(),
          ),
        );
      },
      home: hasSettingsAsync.when(
        data: (hasSettings) {
          if (!hasSettings) {
            return const OnboardingScreen();
          }
          return const MainNavigationScaffold();
        },
        loading: () => const Scaffold(
          backgroundColor: Color(0xFFF7FAF8),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => const OnboardingScreen(),
      ),
    );
  }
}

/// Gates the main application until initial sync (pull & push) has been attempted once,
/// showing a brief branded loading state so the user's data is present immediately.
class InitialSyncGate extends ConsumerStatefulWidget {
  const InitialSyncGate({super.key});

  @override
  ConsumerState<InitialSyncGate> createState() => _InitialSyncGateState();
}

class _InitialSyncGateState extends ConsumerState<InitialSyncGate> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final alreadySynced = ref.read(initialSyncCompletedProvider);
    if (!alreadySynced) {
      _runInitialSync();
    }
  }

  Future<void> _runInitialSync() async {
    setState(() => _isSyncing = true);
    try {
      // 1. Ensure user settings exist
      await ref
          .read(settingsRepositoryProvider)
          .ensureSettingsForCurrentUser();

      // 2. Perform initial fullSync (push & pull) with a safety timeout
      await ref
          .read(syncServiceProvider)
          .fullSync()
          .timeout(const Duration(seconds: 5), onTimeout: () {
            debugPrint('[InitialSyncGate] Initial sync timed out, continuing.');
          });
    } catch (e) {
      debugPrint('[InitialSyncGate] Initial sync error: $e');
    } finally {
      if (mounted) {
        ref.read(initialSyncCompletedProvider.notifier).state = true;
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSynced = ref.watch(initialSyncCompletedProvider);

    if (_isSyncing && !isSynced) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Syncing your ledger...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF60706B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const MainNavigationScaffold();
  }
}

class MainNavigationScaffold extends ConsumerStatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  ConsumerState<MainNavigationScaffold> createState() =>
      _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState
    extends ConsumerState<MainNavigationScaffold> {
  final List<Widget> _screens = const [
    HomeScreen(),
    CustomersScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Customers',
    'History',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabProvider);
    final showSettingsBadge = ref.watch(guestNeedsBackupProvider);
    final settings = ref.watch(settingsStreamProvider).value;
    final shopName = (settings?.shopName.trim().isNotEmpty == true)
        ? settings!.shopName.trim()
        : 'My Shop';

    return Scaffold(
      appBar: AppBar(
        title: currentIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(_titles[currentIndex]),
        centerTitle: false,
        actions: [
          if (currentIndex == 0) ...[
            const HomeUserHeaderAction(),
            const SizedBox(width: 4),
            const SyncStatusIndicator(),
            const SizedBox(width: 8),
          ] else ...[
            const SyncStatusIndicator(),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButton: (currentIndex == 0 || currentIndex == 1)
          ? const QuickActionsFab()
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: const Color(0xFF78909C),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Customers',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: showSettingsBadge,
              backgroundColor: const Color(0xFFB78103),
              child: const Icon(Icons.settings_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: showSettingsBadge,
              backgroundColor: const Color(0xFFB78103),
              child: const Icon(Icons.settings_rounded),
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
