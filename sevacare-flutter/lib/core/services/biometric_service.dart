import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps local_auth + stores opt-in flag in encrypted prefs.
/// Biometric LAYERS ON TOP of OTP — it unlocks the existing stored token.
class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kEnabled = 'seva_biometric_enabled';

  /// True if device supports biometric or PIN authentication.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// True if the user has opted in to biometric unlock.
  static Future<bool> isEnabled() async {
    final v = await _storage.read(key: _kEnabled);
    return v == '1';
  }

  static Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _kEnabled, value: enabled ? '1' : '0');

  /// Prompt biometric/PIN challenge. Returns true on success.
  static Future<bool> authenticate({
    String reason = 'Unlock SevaCare — use your fingerprint or Face ID',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Get a human-readable label for the strongest available biometric.
  static Future<String> biometricLabel() async {
    try {
      final bios = await _auth.getAvailableBiometrics();
      if (bios.contains(BiometricType.face)) return 'Face ID';
      if (bios.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (bios.contains(BiometricType.iris)) return 'Iris Scan';
    } catch (_) {}
    return 'Biometric';
  }
}
