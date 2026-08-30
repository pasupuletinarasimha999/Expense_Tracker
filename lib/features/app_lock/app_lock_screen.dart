import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen gate shown whenever the app returns to the foreground with App Lock enabled.
/// Ported 1:1 from `AppLockActivity.kt` — authenticates against whatever the user already
/// has set up as their device unlock method (fingerprint, face, PIN, or pattern); there is
/// no separate app-specific credential.
class AppLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _auth = LocalAuthentication();
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);

    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        // The screen lock the user had when App Lock was enabled is no longer usable
        // (e.g. they removed their PIN/fingerprint in system settings). Fail open rather
        // than permanently locking them out of their own local data with no recourse.
        ref.read(userPreferencesProvider).isAppLockEnabled = false;
        ref.read(appLockEnabledProvider.notifier).state = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No device screen lock is available anymore, so App Lock has been turned off.')),
          );
        }
        widget.onUnlocked();
        return;
      }

      final success = await _auth.authenticate(
        localizedReason: 'Use your fingerprint, face, or device PIN to continue',
      );
      if (success) {
        widget.onUnlocked();
      }
      // On failure/cancel: leave the lock screen up so the user can tap "Unlock" to retry.
    } catch (error) {
      // A plugin/platform error here (misconfiguration, transient OS issue, etc.) must never
      // leave the user stuck on this screen with no way forward and no explanation — show
      // what happened and let them retry via the same button.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlock failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('Locked', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock with your fingerprint, face, or device PIN to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _authenticating ? null : _authenticate,
                    style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                    child: const Text('Unlock'),
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
