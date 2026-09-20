import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../core/current_user_service.dart';
import '../../core/theme.dart';
import '../auth/account_screen.dart';

/// Top right corner action widget for the Home page.
/// - When in Guest Mode: Displays a "Login / Sign Up" button.
/// - When Authenticated: Displays "Hi [Name]" with Google profile photo or fallback icon.
class HomeUserHeaderAction extends ConsumerWidget {
  const HomeUserHeaderAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.value ?? CurrentUserProfile.guest;

    if (profile.isGuest) {
      return OutlinedButton.icon(
        key: const Key('home_login_signup_button'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AccountScreen(),
            ),
          );
        },
        icon: const Icon(Icons.login_rounded, size: 15),
        label: const Text(
          'Login / Sign Up',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 32),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    return InkWell(
      key: const Key('home_user_profile_button'),
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        // Navigate to the Settings tab where full account details and sign-out live.
        ref.read(currentTabProvider.notifier).state = 3;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(profile.avatarUrl),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 95),
              child: Text(
                'Hi ${profile.displayName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191C1B),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    const double size = 30.0;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(size),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultAvatar(size);
          },
        ),
      );
    }
    return _buildDefaultAvatar(size);
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}
