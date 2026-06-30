import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = online, false = offline.
/// Uses StreamProvider so it rebuilds any widget that watches it.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) =>
        results.isNotEmpty && results.any((r) => r != ConnectivityResult.none),
  );
});

/// One-shot offline check — use in async logic where you can't watch a provider.
Future<bool> isOnline() async {
  final results = await Connectivity().checkConnectivity();
  return results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
}
