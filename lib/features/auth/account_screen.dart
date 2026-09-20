import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/sync/sync_service.dart';
import 'merge_guest_data_dialog.dart';
import 'otp_verification_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const AccountScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  // Sign In tab controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  bool _obscureSignInPassword = true;
  bool _isSigningIn = false;

  // Create Account tab controllers
  final _signUpFormKey = GlobalKey<FormState>();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  bool _obscureSignUpPassword = true;
  bool _isSigningUp = false;

  bool _isMigrating = false;

  /// Subscription to Supabase auth state changes.
  /// Handles async OAuth redirects (e.g. Google sign-in) that complete
  /// outside the immediate await of signInWithOAuth().
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    try {
      _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.signedIn && !_isMigrating) {
          final user = data.session?.user;
          if (user != null) {
            _handlePostSignIn(user.id);
          }
        }
      });
    } catch (_) {
      // Supabase not initialized (e.g. in tests) — skip the subscription.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handlePostSignIn(String userId) async {
    if (!mounted) return;

    try {
      final syncService = ref.read(syncServiceProvider);

      // 1. Resolve settings first: remote cloud settings always take strict precedence
      await syncService.resolveSettingsOnSignIn(userId);

      // 2. Check if local guest customer or transaction data exists
      final hasCustomerData = await syncService.hasLocalGuestCustomerData();

      if (hasCustomerData) {
        final remoteCount = await syncService.getRemoteCustomerCount(userId);
        if (remoteCount > 0) {
          final guestCustomers = await syncService.getLocalGuestCustomerCount();
          final guestTransactions = await syncService.getLocalGuestTransactionCount();
          if (!mounted) return;
          final userEmail = supabase.auth.currentUser?.email ?? 'your account';

          final decision = await showDialog<MergeDecision>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => MergeGuestDataDialog(
              guestCustomerCount: guestCustomers,
              guestTransactionCount: guestTransactions,
              remoteCustomerCount: remoteCount,
              userEmail: userEmail,
            ),
          );

          if (!mounted) return;
          setState(() => _isMigrating = true);

          if (decision == MergeDecision.discardLocal) {
            await syncService.discardGuestData();
          } else {
            await syncService.migrateGuestData(userId, smartMerge: true);
          }
        } else {
          if (mounted) setState(() => _isMigrating = true);
          await syncService.migrateGuestData(userId, smartMerge: true);
        }
      } else {
        if (mounted) setState(() => _isMigrating = true);
        // Clean up any remaining guest data/pending ops
        await syncService.discardGuestData();
      }

      await syncService.fullSync();
      await ref.read(settingsRepositoryProvider).refresh();
    } catch (e) {
      debugPrint('[AccountScreen] Post sign-in migration error: $e');
    } finally {
      if (mounted) {
        // Always land on the Home tab, regardless of which tab was active when
        // the user opened the sign-in screen.
        ref.read(currentTabProvider.notifier).state = 0;
        ref.invalidate(hasLocalSettingsProvider);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScaffold()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _signInWithPassword() async {
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password');
      return;
    }

    setState(() => _isSigningIn = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        await _handlePostSignIn(user.id);
      } else {
        _showError('Sign in succeeded, but no user was returned.');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to sign in. Please check your credentials.');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _signInEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter your email address to reset password');
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showMessage('Password reset instructions sent to $email');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to send reset email. Please try again.');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'baki-khata://login-callback',
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('We could not start Google sign-in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _createAccount() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;

    setState(() => _isSigningUp = true);

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? null : 'baki-khata://login-callback',
      );

      if (!mounted) return;

      final session = response.session;
      if (session != null) {
        // If email confirmation is disabled in Supabase, user is signed in immediately
        await _handlePostSignIn(session.user.id);
        return;
      }

      final user = response.user;
      if (user != null && user.identities != null && user.identities!.isEmpty) {
        _showError('An account with this email already exists. Please sign in instead.');
        return;
      }

      // Email confirmation required -> Navigate to OTP verification
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            password: password,
          ),
        ),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to create account. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isMigrating) {
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
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Setting up your account…',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E2925),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Backing up your offline ledger to the cloud',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF60706B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          title: const Text('Account'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sign In'),
              Tab(text: 'Create Account'),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Baki Khata',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track customer credit, the simple way',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF60706B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        children: [
                          _buildSignInTab(),
                          _buildCreateAccountTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _signInEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _signInPasswordController,
            obscureText: _obscureSignInPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignInPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureSignInPassword = !_obscureSignInPassword;
                  });
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSigningIn ? null : _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isSigningIn ? null : _signInWithPassword,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSigningIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isSigningIn ? null : _signInWithGoogle,
            icon: const _GoogleMark(),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFF263238),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD5DAD8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAccountTab() {
    return SingleChildScrollView(
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signUpEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                final email = value.trim();
                if (!email.contains('@') || !email.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _signUpPasswordController,
              obscureText: _obscureSignUpPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'Minimum 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureSignUpPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureSignUpPassword = !_obscureSignUpPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSigningUp ? null : _createAccount,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSigningUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'By creating an account, you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,)
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
