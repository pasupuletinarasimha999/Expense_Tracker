import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import 'app_lock_screen.dart';

/// Intercepts every app-resume event and shows [AppLockScreen] as a full-screen overlay
/// when App Lock is enabled and the process hasn't been unlocked yet this session. Ported
/// from `ExpenseTrackerApplication`'s `registerActivityLifecycleCallbacks` gate — a
/// `WidgetsBindingObserver` is the closest Flutter equivalent to Android's per-Activity
/// resume callback.
///
/// Deliberately does NOT reactively lock the instant the user flips the Settings toggle on
/// (matches the original: it only checks on the *next* resume, not retroactively while
/// already in the foreground).
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLock();
  }

  void _checkLock() {
    final enabled = ref.read(appLockEnabledProvider);
    final unlocked = ref.read(appLockSessionUnlockedProvider);
    if (enabled && !unlocked && !_locked && mounted) {
      setState(() => _locked = true);
    }
  }

  void _onUnlocked() {
    ref.read(appLockSessionUnlockedProvider.notifier).state = true;
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked) AppLockScreen(onUnlocked: _onUnlocked),
      ],
    );
  }
}
