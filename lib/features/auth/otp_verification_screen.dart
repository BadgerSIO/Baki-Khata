import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/sync/sync_service.dart';
import 'merge_guest_data_dialog.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String? password;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.password,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isMigrating = false;
  String? _inlineError;

  int _resendCooldown = 60;
  int _resendCount = 0;
  Timer? _cooldownTimer;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      if (_inlineError != null) {
        setState(() => _inlineError = null);
      } else {
        setState(() {});
      }
    });
    _startCooldown();

    try {
      _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.signedIn && !_isMigrating) {
          final user = data.session?.user;
          if (user != null) {
            _handlePostVerification(user.id);
          }
        }
      });
    } catch (_) {
      // Supabase not initialized (e.g. in tests)
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handlePostVerification(String userId) async {
    if (!mounted) return;
    setState(() => _isVerifying = false);

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
          final userEmail = widget.email;

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
      debugPrint('[OtpVerificationScreen] Post-verification error: $e');
    } finally {
      if (mounted) {
        ref.read(currentTabProvider.notifier).state = 0;
        ref.invalidate(hasLocalSettingsProvider);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScaffold()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _trySignInWithPassword() async {
    if (widget.password == null || widget.password!.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isVerifying = true;
      _inlineError = null;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: widget.email,
        password: widget.password!,
      );

      final user = response.user;
      if (user != null) {
        await _handlePostVerification(user.id);
      } else {
        setState(() {
          _isVerifying = false;
          _inlineError = 'Please sign in with your credentials.';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _isVerifying = false;
        _inlineError = e.message;
      });
    } catch (_) {
      setState(() {
        _isVerifying = false;
        _inlineError = 'Sign in failed. Please try again.';
      });
    }
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() {
      _isVerifying = true;
      _inlineError = null;
    });

    try {
      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      final session = response.session;
      final userId = session?.user.id ?? supabase.auth.currentUser?.id;

      if (userId != null) {
        await _handlePostVerification(userId);
      } else {
        setState(() {
          _inlineError =
              'Verification succeeded, but no active session was returned. Please sign in.';
          _isVerifying = false;
        });
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already confirmed') &&
          widget.password != null) {
        await _trySignInWithPassword();
        return;
      }
      setState(() {
        _inlineError = e.message;
        _isVerifying = false;
      });
    } catch (_) {
      setState(() {
        _inlineError = 'Verification failed. Please check the code and try again.';
        _isVerifying = false;
      });
    }
  }

  Future<void> _handleResend() async {
    if (_resendCount >= 5 || _resendCooldown > 0) return;

    setState(() {
      _resendCount++;
      _inlineError = null;
    });

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification code resent to ${widget.email}')),
        );
      }

      _startCooldown();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend code. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canVerify = _codeController.text.trim().length == 6 &&
        !_isVerifying &&
        !_isMigrating;

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

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 34,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Check your email',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF60706B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE0E5E2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            textAlign: TextAlign.center,
                            autofocus: true,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 10,
                              color: Color(0xFF1E2925),
                            ),
                            decoration: InputDecoration(
                              hintText: '------',
                              hintStyle: TextStyle(
                                letterSpacing: 10,
                                color: Colors.grey.shade400,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                          ),
                          if (_inlineError != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 16,
                                  color: AppColors.debtText,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _inlineError!,
                                    style: const TextStyle(
                                      color: AppColors.debtText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: canVerify ? _handleVerify : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: _resendCount >= 5
                        ? const Text(
                            'Too many attempts — try again in a few minutes',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.debtText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : _resendCooldown > 0
                            ? Text(
                                'Resend code in ${_resendCooldown}s',
                                style: const TextStyle(
                                  color: Color(0xFF78909C),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : TextButton(
                                onPressed: _handleResend,
                                child: const Text(
                                  'Resend code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _isVerifying || _isMigrating
                          ? null
                          : _trySignInWithPassword,
                      child: Text(
                        widget.password != null
                            ? 'Confirmed via email link? Tap to finish'
                            : 'Already confirmed? Sign in',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF60706B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
