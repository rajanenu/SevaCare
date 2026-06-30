/// Compile-time environment configuration.
///
/// Web build (default):
///   flutter build web
///
/// Android APK build (local Wi-Fi testing):
///   flutter build apk --dart-define=LOCAL_BACKEND_HOST=192.168.29.242
///
/// Production:
///   flutter build apk --dart-define=API_BASE_URL=https://api.sevacare.in/api/v1
class AppConfig {
  AppConfig._();

  // ── Build-time constants ───────────────────────────────────────────────────
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'local');
  // Backend runs on 8080 locally; override with --dart-define=API_PORT=443 in production.
  static const String _apiPort = String.fromEnvironment('API_PORT', defaultValue: '8080');

  // For Android APK: set to your Mac's local Wi-Fi IP so the phone can reach
  // the backend over the same network. Example:
  //   flutter build apk --dart-define=LOCAL_BACKEND_HOST=192.168.29.242
  static const String _localBackendHost =
      String.fromEnvironment('LOCAL_BACKEND_HOST', defaultValue: 'localhost');

  // Full override — takes priority over everything else.
  // flutter build apk --dart-define=API_BASE_URL=https://api.sevacare.in/api/v1
  static const String _apiBaseOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  // ── Environment flags ──────────────────────────────────────────────────────
  static bool get isLocal => _env == 'local';
  static bool get isProduction => _env == 'production';
  static String get environment => _env;

  // ── API base URL ───────────────────────────────────────────────────────────
  /// Resolution order:
  ///   1. API_BASE_URL dart-define (full override — production or custom)
  ///   2. Web: derives host from the browser's serving URL (works for flutter web)
  ///   3. Native (Android/iOS): uses LOCAL_BACKEND_HOST dart-define (default: localhost)
  static String get apiBaseUrl {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    try {
      final uri = Uri.base;
      final host = uri.host;
      if (host.isNotEmpty) {
        return '${uri.scheme}://$host:${int.parse(_apiPort)}/api/v1';
      }
    } catch (_) {}
    // Native fallback — uses LOCAL_BACKEND_HOST (set at build time for LAN testing)
    return 'http://$_localBackendHost:$_apiPort/api/v1';
  }

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static Duration get connectTimeout =>
      isProduction ? const Duration(seconds: 10) : const Duration(seconds: 15);
  static Duration get receiveTimeout =>
      isProduction ? const Duration(seconds: 20) : const Duration(seconds: 30);

  // ── Feature flags ──────────────────────────────────────────────────────────
  static bool get enableDebugBanner => isLocal;
  static bool get enableHaptics => true;
}
