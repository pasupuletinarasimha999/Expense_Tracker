import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../settings/settings_providers.dart';

/// Ported 1:1 from `AuthActivity.kt` + `AuthViewModel.kt`.
///
/// Google Sign-In and Drive sync are fully wired here, but will not actually authenticate
/// until a real Google Cloud OAuth client is configured for this app (see project README).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final googleSignIn = ref.read(googleSignInProvider);

    try {
      // Sign out any cached session first so the account chooser always appears, letting
      // the user pick (and re-consent as) a different account if they want.
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled the picker.
        setState(() => _loading = false);
        return;
      }

      await ref.read(authRepositoryProvider).handleGoogleSignIn(account);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Signed in with Google! Restored your Drive backup.')));
      // These read from SharedPreferences/Drive state that handleGoogleSignIn just changed —
      // without invalidating them here, screens could keep showing the *previous* signed-in
      // account's name/email/currency after switching accounts, even though the underlying
      // data has already changed.
      ref.invalidate(currencySymbolProvider);
      ref.invalidate(darkModeProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(lastSyncTimeProvider);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.account_balance_wallet, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text('Expense Tracker', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Sign in to sync your expenses across devices',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                _FeatureRow(icon: Icons.verified_user_outlined, text: 'Verified Google Auth'),
                const SizedBox(height: 12),
                _FeatureRow(icon: Icons.cloud_sync_outlined, text: 'Auto Cloud Backup & Multi-Device Restore'),
                const SizedBox(height: 12),
                _FeatureRow(icon: Icons.picture_as_pdf_outlined, text: 'Export PDF/CSV to Gmail'),
                const SizedBox(height: 32),
                if (_loading)
                  const CircularProgressIndicator()
                else
                  OutlinedButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), padding: const EdgeInsets.symmetric(horizontal: 24)),
                  ),
                const SizedBox(height: 24),
                Text(
                  'By signing in, you agree that your data will be stored privately in your own Google Drive.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
