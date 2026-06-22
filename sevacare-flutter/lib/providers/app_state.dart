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

  const AuthState({
    this.token,
    this.tenantPublicId,
    this.subjectPublicId,
    this.role,
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

// ── Auth Provider ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.unauthenticated);

  Future<void> setSession(AuthenticatedSession session) async {
    final role = UserRoleX.fromApi(session.role);
    state = AuthState(
      token: session.token,
      tenantPublicId: session.tenantPublicId,
      subjectPublicId: session.subjectPublicId,
      role: role,
    );
    await _storage.write(key: _kToken, value: session.token);
    await _storage.write(key: _kTenantId, value: session.tenantPublicId);
    await _storage.write(key: _kSubjectId, value: session.subjectPublicId);
    await _storage.write(key: _kRole, value: session.role);
  }

  Future<void> clearSession() async {
    state = AuthState.unauthenticated;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kTenantId);
    await _storage.delete(key: _kSubjectId);
    await _storage.delete(key: _kRole);
  }

  Future<bool> restore() async {
    final token = await _storage.read(key: _kToken);
    final tenantId = await _storage.read(key: _kTenantId);
    final subjectId = await _storage.read(key: _kSubjectId);
    final roleStr = await _storage.read(key: _kRole);
    if (token != null && token.isNotEmpty) {
      state = AuthState(
        token: token,
        tenantPublicId: tenantId,
        subjectPublicId: subjectId,
        role: roleStr != null ? UserRoleX.fromApi(roleStr) : null,
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
