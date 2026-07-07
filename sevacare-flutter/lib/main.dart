import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Restore persisted auth + hospital selection before first frame
  final container = ProviderContainer();
  await Future.wait([
    container.read(authProvider.notifier).restore(),
    container.read(hospitalProvider.notifier).restore(),
  ]);

  // Decide whether to play the cinematic intro. The OS routinely kills a
  // backgrounded app to reclaim memory and cold-restarts it on resume — which
  // used to replay the full 6s intro every time the user came back after a
  // minute in another app. We now only play it on a genuinely fresh launch:
  // if it was shown within the cooldown window we skip it and drop the user
  // straight back onto their restored page.
  final prefs = await SharedPreferences.getInstance();
  final lastIntroMs = prefs.getInt('intro_last_shown_ms') ?? 0;
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
