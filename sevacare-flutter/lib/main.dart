import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock only makes sense on phones — skip on web (where `Platform`
  // isn't available) and desktop (where windows are freely resizable).
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await _guard(
      'orientation lock',
      () => SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
  }

  // Restore persisted auth + hospital selection before the first frame.
  //
  // Nothing in this function may block `runApp` indefinitely. Android's
  // keystore-backed secure storage can throw (BadPaddingException, "key user
  // not authenticated") or stall after the OS has killed a long-idle app, and
  // an error escaping before the first frame leaves the user staring at a
  // black window until they force-stop the process. A failed restore only
  // means "log in again" — never "no UI at all".
  final container = ProviderContainer();
  await _guard(
    'session restore',
    () => Future.wait([
      container.read(authProvider.notifier).restore(),
      container.read(hospitalProvider.notifier).restore(),
    ]),
  );

  // Decide whether to play the cinematic intro. The OS routinely kills a
  // backgrounded app to reclaim memory and cold-restarts it on resume — which
  // used to replay the full 6s intro every time the user came back after a
  // minute in another app. We now only play it on a genuinely fresh launch:
  // if it was shown within the cooldown window we skip it and drop the user
  // straight back onto their restored page.
  final lastIntroMs = await _guard<int>(
        'intro cooldown read',
        () async => (await SharedPreferences.getInstance())
                .getInt('intro_last_shown_ms') ??
            0,
      ) ??
      0;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  const introCooldownMs = 30 * 60 * 1000; // 30 minutes
  final showIntro = nowMs - lastIntroMs > introCooldownMs;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: SevaCareApp(showIntro: showIntro),
    ),
  );
}

/// Runs a startup step that must never keep the first frame from rendering:
/// bounded by a timeout, swallowing failures, resolving to null when the step
/// does not complete.
Future<T?> _guard<T>(String step, Future<T> Function() run) async {
  try {
    return await run().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('SevaCare startup: "$step" failed, continuing without it — $e');
    return null;
  }
}
