/// Compile-time environment configuration.
/// Inject values via: flutter build web --dart-define=ENV=production --dart-define=API_PORT=8081
class AppConfig {
  AppConfig._();

  // ── Build-time constants ───────────────────────────────────────────────────
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'local');
  static const String _apiPort = String.fromEnvironment('API_PORT', defaultValue: '8081');

  // Allow a fully-qualified override for non-standard deployments:
  // flutter build web --dart-define=API_BASE_URL=https://api.sevacare.in/api/v1
  static const String _apiBaseOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  // ── Environment flags ──────────────────────────────────────────────────────
  static bool get isLocal => _env == 'local';
  static bool get isProduction => _env == 'production';
  static String get environment => _env;

  // ── API base URL (resolved at runtime from current host) ───────────────────
  /// Automatically adapts to wherever the app is served (localhost or LAN IP).
  /// Override at build time with --dart-define=API_BASE_URL=... for production.
  static String get apiBaseUrl {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    try {
      final uri = Uri.base;
      final host = uri.host;
      if (host.isNotEmpty) {
        return '${uri.scheme}://$host:$_apiPort/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:$_apiPort/api/v1';
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
