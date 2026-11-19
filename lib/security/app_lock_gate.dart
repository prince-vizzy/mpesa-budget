import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_lock.dart';
import 'pin_views.dart';

/// Sits above the Navigator (through MaterialApp.builder), so the lock screen
/// covers every route and dialog, not just the home screen.
///
/// The app locks whenever it leaves the screen: switching apps, going home or
/// turning the screen off. Permission dialogs and the fingerprint prompt only
/// make the app inactive, not paused, so they don't trigger it.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _lock = AppLock.instance;

  // Replaced each time the app locks, so the lock screen starts fresh: the
  // fingerprint prompt reopens and old error text doesn't linger.
  Object _lockSession = Object();
  bool _wasLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lock.addListener(_onLockChanged);
    if (!_lock.isLoaded) _lock.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock.removeListener(_onLockChanged);
    super.dispose();
  }

  void _onLockChanged() {
    if (!mounted) return;
    setState(() {
      final locked = _lock.isLocked;
      if (locked && !_wasLocked) _lockSession = Object();
      _wasLocked = locked;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _lock.onBackgrounded();
  }

  @override
  Widget build(BuildContext context) {
    final covered = !_lock.isLoaded || _lock.isLocked;
    return Stack(
      children: [
        // Kept in the tree while locked so the app returns exactly where it
        // was, but hidden from screen readers and taps.
        ExcludeSemantics(
          excluding: covered,
          child: IgnorePointer(ignoring: covered, child: widget.child),
        ),
        if (!_lock.isLoaded)
          // Blank cover until settings load, so nothing flashes on launch.
          const Positioned.fill(
            child: ColoredBox(color: AppColors.mainBackground),
          )
        else if (_lock.isLocked)
          Positioned.fill(
            child: Material(
              color: AppColors.mainBackground,
              child: PinVerifyView(
                key: ObjectKey(_lockSession),
                title: 'Enter your PIN',
                autoBiometric: true,
                allowForgot: true,
                onVerified: () {},
              ),
            ),
          ),
      ],
    );
  }
}
