import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_colors.dart';
import '../data/models/models.dart';
import '../repositories/sevacare_repository.dart';

// ── Storage keys ──────────────────────────────────────────────────────────────
const _kToken = 'seva_token';
const _kTenantId = 'seva_tenant_id';
const _kSubjectId = 'seva_subject_id';
const _kRole = 'seva_role';
const _kIsGeneric = 'seva_is_generic';
const _kSubjectName = 'seva_subject_name';
const _kUserType = 'seva_user_type';
const _kHospitalId = 'seva_hospital_id';
const _kTheme = 'seva_theme';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Selected Hospital ─────────────────────────────────────────────────────────

class HospitalState {
  final String tenantPublicId;
  final String hospitalName;
  final TenantTheme theme;

  const HospitalState({
    required this.tenantPublicId,
    required this.hospitalName,
    required this.theme,
  });

  static const empty = HospitalState(
    tenantPublicId: '',
    hospitalName: 'SevaCare',
    theme: TenantTheme.premium,
  );
}

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final String? token;
  final String? tenantPublicId;
  final String? subjectPublicId;
  final UserRole? role;
  final bool isGenericAdmin;
  final String subjectName;
  final String userType;

  const AuthState({
    this.token,
    this.tenantPublicId,
    this.subjectPublicId,
    this.role,
    this.isGenericAdmin = false,
    this.subjectName = '',
    this.userType = 'ADMIN',
  });

  bool get isAuthenticated =>
      token != null && token!.isNotEmpty && subjectPublicId != null;

  static const unauthenticated = AuthState();
}

// ── Booking Form State ────────────────────────────────────────────────────────

class BookingFormState {
  final String name;
  final String gender;
  final String age;
  final String mobile;
  final String address;
  final String email;
  final String specialty;
  final String selectedDoctorId;
  final String selectedDate;
  final String selectedSlot;
  final String bookingType; // 'SLOT' or 'TOKEN'
  final String? tokenSession; // 'MORNING' or 'EVENING', only when bookingType == 'TOKEN'

  const BookingFormState({
    this.name = '',
    this.gender = 'male',
    this.age = '',
    this.mobile = '',
    this.address = '',
    this.email = '',
    this.specialty = 'General Physician',
    this.selectedDoctorId = '',
    this.selectedDate = '',
    this.selectedSlot = '',
    this.bookingType = 'SLOT',
    this.tokenSession,
  });

  BookingFormState copyWith({
    String? name,
    String? gender,
    String? age,
    String? mobile,
    String? address,
    String? email,
    String? specialty,
    String? selectedDoctorId,
    String? selectedDate,
    String? selectedSlot,
    String? bookingType,
    String? tokenSession,
    bool clearTokenSession = false,
  }) =>
      BookingFormState(
        name: name ?? this.name,
        gender: gender ?? this.gender,
        age: age ?? this.age,
        mobile: mobile ?? this.mobile,
        address: address ?? this.address,
        email: email ?? this.email,
        specialty: specialty ?? this.specialty,
        selectedDoctorId: selectedDoctorId ?? this.selectedDoctorId,
        selectedDate: selectedDate ?? this.selectedDate,
        selectedSlot: selectedSlot ?? this.selectedSlot,
        bookingType: bookingType ?? this.bookingType,
        tokenSession: clearTokenSession ? null : (tokenSession ?? this.tokenSession),
      );
}

// ── Hospital Provider ─────────────────────────────────────────────────────────

class HospitalNotifier extends StateNotifier<HospitalState> {
  HospitalNotifier() : super(HospitalState.empty);

  void selectHospital(TenantSummary tenant) {
    final theme = tenant.themeKey == 'clinic' ? TenantTheme.clinic : TenantTheme.premium;
    state = HospitalState(
      tenantPublicId: tenant.tenantPublicId,
      hospitalName: tenant.hospitalName,
      theme: theme,
    );
    _persist(tenant.tenantPublicId, tenant.themeKey);
  }

  Future<void> _persist(String tenantId, String themeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHospitalId, tenantId);
    await prefs.setString(_kTheme, themeKey);
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kHospitalId);
    final themeKey = prefs.getString(_kTheme) ?? 'premium';
    if (id != null && id.isNotEmpty) {
      final theme = themeKey == 'clinic' ? TenantTheme.clinic : TenantTheme.premium;
      state = HospitalState(tenantPublicId: id, hospitalName: '', theme: theme);
    }
  }
}

final hospitalProvider = StateNotifierProvider<HospitalNotifier, HospitalState>(
  (_) => HospitalNotifier(),
);

/// Hospital hero image (glassmorphism login background), decoded once per
/// tenant and cached by Riverpod. Purely decorative — resolves to null on any
/// failure so login never blocks on it.
final tenantHeroImageProvider =
    FutureProvider.family<Uint8List?, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return null;
  try {
    final b64 =
        await ref.watch(repositoryProvider).getTenantHeroImageBase64(tenantId);
    if (b64 == null) return null;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
});

/// Backend-synced doctor photo, so an uploaded photo is visible to patients
/// booking on a different device — not just on the doctor's own phone.
/// Resolves to null (falls back to the bundled stock photo) on any failure,
/// including when the viewer isn't authenticated yet.
final doctorPhotoProvider =
    FutureProvider.family<Uint8List?, String>((ref, doctorId) async {
  if (doctorId.isEmpty) return null;
  final auth = ref.watch(authProvider);
  final tenantId = auth.tenantPublicId;
  final token = auth.token;
  if (tenantId == null || tenantId.isEmpty || token == null || token.isEmpty) {
    return null;
  }
  try {
    final photo = await ref.watch(repositoryProvider).getDoctorPhoto(tenantId, doctorId, token);
    if (photo.photoBase64 == null || photo.photoBase64!.isEmpty) return null;
    return base64Decode(photo.photoBase64!);
  } catch (_) {
    return null;
  }
});

// ── Auth Provider ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.unauthenticated);

  Future<void> setSession(AuthenticatedSession session) async {
    final role = UserRoleX.fromApi(session.role, userType: session.userType);
    state = AuthState(
      token: session.token,
      tenantPublicId: session.tenantPublicId,
      subjectPublicId: session.subjectPublicId,
      role: role,
      isGenericAdmin: session.isGeneric,
      subjectName: session.subjectName,
      userType: session.userType,
    );
    await _storage.write(key: _kToken, value: session.token);
    await _storage.write(key: _kTenantId, value: session.tenantPublicId);
    await _storage.write(key: _kSubjectId, value: session.subjectPublicId);
    await _storage.write(key: _kRole, value: session.role);
    await _storage.write(key: _kIsGeneric, value: session.isGeneric ? '1' : '0');
    await _storage.write(key: _kSubjectName, value: session.subjectName);
    await _storage.write(key: _kUserType, value: session.userType);
  }

  /// Clears in-memory session.
  ///
  /// If [wipeStorage] is false (the default for user-initiated sign-out) and
  /// biometric unlock is enabled, the encrypted credentials stay in secure
  /// storage so biometric can restore the session without OTP.
  ///
  /// Pass [wipeStorage] = true for:
  ///   - 401 auto-logout (token is expired — keeping it is pointless)
  ///   - "Sign out fully / disable biometric" user action
  Future<void> clearSession({bool wipeStorage = false}) async {
    state = AuthState.unauthenticated;
    if (wipeStorage) {
      await _storage.delete(key: _kToken);
      await _storage.delete(key: _kTenantId);
      await _storage.delete(key: _kSubjectId);
      await _storage.delete(key: _kRole);
      await _storage.delete(key: _kIsGeneric);
      await _storage.delete(key: _kSubjectName);
      await _storage.delete(key: _kUserType);
    }
    // When wipeStorage is false, credentials stay encrypted in secure storage.
    // Only biometric auth can re-activate the session (via restore()).
  }

  /// Keeps the in-memory (and persisted) session name in sync right after a
  /// profile save, so screens reading `auth.subjectName` directly (e.g. the
  /// dashboard greeting) don't show a stale name until the next full login.
  Future<void> updateSubjectName(String name) async {
    state = AuthState(
      token: state.token,
      tenantPublicId: state.tenantPublicId,
      subjectPublicId: state.subjectPublicId,
      role: state.role,
      isGenericAdmin: state.isGenericAdmin,
      subjectName: name,
      userType: state.userType,
    );
    await _storage.write(key: _kSubjectName, value: name);
  }

  Future<bool> restore() async {
    final token = await _storage.read(key: _kToken);
    final tenantId = await _storage.read(key: _kTenantId);
    final subjectId = await _storage.read(key: _kSubjectId);
    final roleStr = await _storage.read(key: _kRole);
    final isGeneric = await _storage.read(key: _kIsGeneric);
    final subjectName = await _storage.read(key: _kSubjectName);
    final userType = await _storage.read(key: _kUserType) ?? 'ADMIN';
    if (token != null && token.isNotEmpty) {
      state = AuthState(
        token: token,
        tenantPublicId: tenantId,
        subjectPublicId: subjectId,
        role: roleStr != null ? UserRoleX.fromApi(roleStr, userType: userType) : null,
        isGenericAdmin: isGeneric == '1',
        subjectName: subjectName ?? '',
        userType: userType,
      );
      return true;
    }
    return false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);

// ── Booking Form Provider ─────────────────────────────────────────────────────

class BookingFormNotifier extends StateNotifier<BookingFormState> {
  BookingFormNotifier() : super(const BookingFormState());

  void updateName(String v) => state = state.copyWith(name: v);
  void updateGender(String v) => state = state.copyWith(gender: v);
  void updateAge(String v) => state = state.copyWith(age: v);
  void updateMobile(String v) => state = state.copyWith(mobile: v);
  void updateAddress(String v) => state = state.copyWith(address: v);
  void updateEmail(String v) => state = state.copyWith(email: v);
  void updateSpecialty(String v) => state = state.copyWith(specialty: v);
  void updateDoctorId(String v) => state = state.copyWith(selectedDoctorId: v);
  void updateDate(String v) => state = state.copyWith(selectedDate: v);
  void updateSlot(String v) => state = state.copyWith(selectedSlot: v);
  void updateBookingType(String v) => state = state.copyWith(bookingType: v, clearTokenSession: true);
  void updateTokenSession(String v) => state = state.copyWith(tokenSession: v);

  void setMobileFromLogin(String mobile) {
    state = state.copyWith(mobile: mobile);
  }

  void reset() => state = const BookingFormState();
}

final bookingFormProvider = StateNotifierProvider<BookingFormNotifier, BookingFormState>(
  (_) => BookingFormNotifier(),
);

// ── Repository Provider ───────────────────────────────────────────────────────

final repositoryProvider = Provider<SevaCareRepository>(
  (_) => SevaCareRepository(apiClient),
);

// ── Misc providers ────────────────────────────────────────────────────────────

// Tracks doctor's selected patient for prescription upload
final doctorSelectedPatientIdProvider = StateProvider<String?>((ref) => null);
final doctorSelectedAppointmentIdProvider = StateProvider<String?>((ref) => null);
// Full queue facet for the appointment being consulted — carries intake
// symptoms and IP-Staff vitals into the consultation screen.
final doctorSelectedFacetProvider = StateProvider<DoctorQueueFacetView?>((ref) => null);

// Login form state
class LoginFormState {
  final String identifier;
  final String email;
  final String otp;
  final bool otpSent;
  final bool sending;
  final String? error;

  const LoginFormState({
    this.identifier = '',
    this.email = '',
    this.otp = '0000',
    this.otpSent = false,
    this.sending = false,
    this.error,
  });

  LoginFormState copyWith({
    String? identifier,
    String? email,
    String? otp,
    bool? otpSent,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      LoginFormState(
        identifier: identifier ?? this.identifier,
        email: email ?? this.email,
        otp: otp ?? this.otp,
        otpSent: otpSent ?? this.otpSent,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

class LoginFormNotifier extends StateNotifier<LoginFormState> {
  LoginFormNotifier() : super(const LoginFormState());

  void setIdentifier(String v) => state = state.copyWith(identifier: v);
  void setEmail(String v) => state = state.copyWith(email: v);
  void setOtp(String v) => state = state.copyWith(otp: v);
  void markOtpSent() => state = state.copyWith(otpSent: true, sending: false, clearError: true);
  void setSending(bool v) => state = state.copyWith(sending: v);
  void setError(String msg) => state = state.copyWith(error: msg, sending: false);
  void reset() => state = const LoginFormState();
  void resetOtp() => state = state.copyWith(otpSent: false);
}

final loginFormProvider = StateNotifierProvider.autoDispose<LoginFormNotifier, LoginFormState>(
  (_) => LoginFormNotifier(),
);

// Active role selection on login screen (before auth)
final activeRoleProvider = StateProvider<UserRole>((ref) => UserRole.patient);

// ── Dark Mode ─────────────────────────────────────────────────────────────────

final darkModeProvider = StateProvider<bool>((ref) => false);

/// Stores the mobile number the user logged in with, for profile pre-fill.
final loginMobileProvider = StateProvider<String>((ref) => '');
