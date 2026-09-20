import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class CurrentUserProfile {
  final String id;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final bool isGuest;

  const CurrentUserProfile({
    required this.id,
    this.email,
    required this.displayName,
    this.avatarUrl,
    required this.isGuest,
  });

  static const guest = CurrentUserProfile(
    id: CurrentUserService.guestSentinel,
    displayName: 'Guest',
    avatarUrl: null,
    isGuest: true,
  );
}

class CurrentUserService {
  static const String guestSentinel = 'local_guest';
  final SupabaseClient? _supabase;

  CurrentUserService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient;

  String get effectiveUserId {
    try {
      final client = _supabase ?? SupabaseConfig.client;
      final user = client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    } catch (_) {}
    return guestSentinel;
  }

  bool get isGuest => effectiveUserId == guestSentinel;

  bool get isAuthenticated => !isGuest;

  CurrentUserProfile get profile {
    try {
      final client = _supabase ?? SupabaseConfig.client;
      final user = client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return CurrentUserProfile(
          id: user.id,
          email: user.email,
          displayName: extractFirstName(user),
          avatarUrl: extractAvatarUrl(user),
          isGuest: false,
        );
      }
    } catch (_) {}
    return CurrentUserProfile.guest;
  }

  static String extractFirstName(User user) {
    final meta = user.userMetadata;
    final givenName = meta?['given_name'] as String?;
    if (givenName != null && givenName.trim().isNotEmpty) {
      return givenName.trim();
    }
    final fullName = (meta?['full_name'] ?? meta?['name']) as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(RegExp(r'\s+')).first;
    }
    if (user.identities != null) {
      for (final id in user.identities!) {
        final idData = id.identityData;
        final idName = (idData?['given_name'] ?? idData?['full_name'] ?? idData?['name']) as String?;
        if (idName != null && idName.trim().isNotEmpty) {
          return idName.trim().split(RegExp(r'\s+')).first;
        }
      }
    }
    if (user.email != null && user.email!.contains('@')) {
      final prefix = user.email!.split('@').first.trim();
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + (prefix.length > 1 ? prefix.substring(1) : '');
      }
    }
    return 'User';
  }

  static String? extractAvatarUrl(User user) {
    final meta = user.userMetadata;
    final url = (meta?['avatar_url'] ?? meta?['picture']) as String?;
    if (url != null && url.trim().isNotEmpty) {
      return url.trim();
    }
    if (user.identities != null) {
      for (final id in user.identities!) {
        final idUrl = (id.identityData?['avatar_url'] ?? id.identityData?['picture']) as String?;
        if (idUrl != null && idUrl.trim().isNotEmpty) {
          return idUrl.trim();
        }
      }
    }
    return null;
  }
}

final currentUserServiceProvider = Provider<CurrentUserService>((ref) {
  return CurrentUserService();
});

/// Reactively emits the effective user ID whenever auth state changes.
/// Emits the authenticated user's ID on sign-in, and [CurrentUserService.guestSentinel]
/// on sign-out or when Supabase is not initialized (e.g. in tests via override).
final currentUserIdProvider = StreamProvider<String>((ref) async* {
  // Emit the current value immediately so the UI is never blank on first frame.
  yield ref.read(currentUserServiceProvider).effectiveUserId;

  try {
    await for (final data in SupabaseConfig.client.auth.onAuthStateChange) {
      final user = data.session?.user;
      if (user != null && user.id.isNotEmpty) {
        yield user.id;
      } else {
        yield CurrentUserService.guestSentinel;
      }
    }
  } catch (_) {
    // Supabase not initialized (test environment) — stay on the initial value.
  }
});

/// Reactively emits the [CurrentUserProfile] whenever auth state changes.
/// Emits the profile with display name and avatar on sign-in, and
/// [CurrentUserProfile.guest] when unauthenticated or signed out.
final currentUserProfileProvider = StreamProvider<CurrentUserProfile>((ref) async* {
  yield ref.read(currentUserServiceProvider).profile;

  try {
    await for (final _ in SupabaseConfig.client.auth.onAuthStateChange) {
      yield ref.read(currentUserServiceProvider).profile;
    }
  } catch (_) {
    // Supabase not initialized (test environment) — stay on the initial value.
  }
});
