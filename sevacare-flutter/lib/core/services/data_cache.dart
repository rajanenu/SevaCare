import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';

/// Lightweight SharedPreferences cache for data critical mid-workflow.
/// Cached: doctor roster, today's patient queue.
/// A dropped connection during consultation won't blank the screen.
class DataCache {
  DataCache._();

  static const _kDoctors   = 'cache_doctors_v1';
  static const _kQueue     = 'cache_queue_v1';
  static const _kQueueDate = 'cache_queue_date_v1';

  // ── Doctors ────────────────────────────────────────────────────────────────

  static Future<void> saveDoctors(List<DoctorRecord> docs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kDoctors,
      jsonEncode(docs.map((d) => _doctorToJson(d)).toList()),
    );
  }

  static Future<List<DoctorRecord>> loadDoctors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDoctors);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => DoctorRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Doctor Queue ───────────────────────────────────────────────────────────

  static Future<void> saveQueue(
      String date, List<AppointmentRecord> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQueueDate, date);
    await prefs.setString(
      _kQueue,
      jsonEncode(queue.map((a) => _apptToJson(a)).toList()),
    );
  }

  /// Returns cached queue only if it matches [date]; otherwise empty.
  static Future<List<AppointmentRecord>> loadQueue(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kQueueDate) != date) return [];
      final raw = prefs.getString(_kQueue);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AppointmentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _apptToJson(AppointmentRecord a) => {
        'appointmentPublicId': a.appointmentPublicId,
        'patientPublicId': a.patientPublicId,
        'doctorPublicId': a.doctorPublicId,
        'slot': a.slot,
        'status': a.status,
        if (a.note != null) 'note': a.note,
      };

  static Map<String, dynamic> _doctorToJson(DoctorRecord d) => {
        'doctorPublicId': d.doctorPublicId,
        'tenantPublicId': d.tenantPublicId,
        'fullName': d.fullName,
        'specialty': d.specialty,
        'availability': d.availability,
        'fee': d.fee,
        'active': d.active,
        if (d.age != null) 'age': d.age,
        if (d.address != null) 'address': d.address,
        if (d.aboutMe != null) 'aboutMe': d.aboutMe,
        if (d.experience != null) 'experience': d.experience,
        if (d.imageUrl != null) 'imageUrl': d.imageUrl,
        if (d.mobileNumber != null) 'mobileNumber': d.mobileNumber,
        if (d.email != null) 'email': d.email,
        if (d.qualifications != null) 'qualifications': d.qualifications,
        if (d.availableFrom != null) 'availableFrom': d.availableFrom,
        if (d.readyToLookPatients != null)
          'readyToLookPatients': d.readyToLookPatients,
      };
}
