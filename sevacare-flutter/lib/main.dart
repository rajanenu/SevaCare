import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Restore persisted auth + hospital selection before first frame
  final container = ProviderContainer();
  await Future.wait([
    container.read(authProvider.notifier).restore(),
    container.read(hospitalProvider.notifier).restore(),
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SevaCareApp(),
    ),
  );
}
