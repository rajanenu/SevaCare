import 'dart:async';

import 'package:flutter/material.dart';

/// Near-real-time updates without push infrastructure: screens mix this in and
/// call [startAutoRefresh] with a silent reload callback. The timer skips ticks
/// while the app is backgrounded, the route is covered by another page/dialog,
/// or the keyboard is open (so a refresh never clobbers what the user is
/// typing). Callbacks must NOT flip a loading spinner — data should swap in
/// place.
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoRefreshTimer;
  Future<void> Function()? _onAutoRefresh;
  _LifecycleObserver? _lifecycleObserver;
  bool _refreshInFlight = false;
  bool _appActive = true;

  static const defaultInterval = Duration(seconds: 20);

  void startAutoRefresh(Future<void> Function() onTick,
      {Duration interval = defaultInterval}) {
    _onAutoRefresh = onTick;
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _LifecycleObserver(_onLifecycleChange);
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) => _tick());
  }

  void _onLifecycleChange(AppLifecycleState state) {
    final wasActive = _appActive;
    _appActive = state == AppLifecycleState.resumed;
    // Coming back to the foreground: refresh immediately instead of waiting
    // out the remainder of the interval.
    if (_appActive && !wasActive) _tick();
  }

  Future<void> _tick() async {
    if (!mounted || !_appActive || _refreshInFlight || _onAutoRefresh == null) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
    _refreshInFlight = true;
    try {
      await _onAutoRefresh!.call();
    } catch (_) {
      // Silent by design — the next tick retries; the screen keeps stale data.
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    super.dispose();
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  final void Function(AppLifecycleState) onChange;
  _LifecycleObserver(this.onChange);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}
