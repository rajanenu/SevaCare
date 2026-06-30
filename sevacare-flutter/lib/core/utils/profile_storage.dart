import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists profile fields locally (SharedPreferences), keyed by userId.
/// Patient name/age/gender/email/address are also pushed to the backend,
/// but photo and bloodGroup are stored only here (no upload API).
class ProfileStorage {
  ProfileStorage._();

  static String _k(String userId, String field) => 'profile_${userId}_$field';

  static Future<ProfileData> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileData(
      name: prefs.getString(_k(userId, 'name')) ?? '',
      age: prefs.getString(_k(userId, 'age')) ?? '',
      gender: prefs.getString(_k(userId, 'gender')) ?? 'male',
      email: prefs.getString(_k(userId, 'email')) ?? '',
      address: prefs.getString(_k(userId, 'address')) ?? '',
      bloodGroup: prefs.getString(_k(userId, 'bloodGroup')) ?? '',
      photoB64: prefs.getString(_k(userId, 'photoB64')),
    );
  }

  static Future<void> save(String userId, ProfileData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(userId, 'name'), data.name);
    await prefs.setString(_k(userId, 'age'), data.age);
    await prefs.setString(_k(userId, 'gender'), data.gender);
    await prefs.setString(_k(userId, 'email'), data.email);
    await prefs.setString(_k(userId, 'address'), data.address);
    await prefs.setString(_k(userId, 'bloodGroup'), data.bloodGroup);
    if (data.photoB64 != null) {
      await prefs.setString(_k(userId, 'photoB64'), data.photoB64!);
    } else {
      await prefs.remove(_k(userId, 'photoB64'));
    }
  }

  static Future<void> savePhoto(String userId, String b64) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(userId, 'photoB64'), b64);
  }

  static Future<void> clearPhoto(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(userId, 'photoB64'));
  }

  static String? bytesToB64(List<int>? bytes) =>
      bytes == null ? null : base64Encode(bytes);

  static List<int>? b64ToBytes(String? b64) =>
      b64 == null || b64.isEmpty ? null : base64Decode(b64);
}

class ProfileData {
  final String name;
  final String age;
  final String gender;
  final String email;
  final String address;
  final String bloodGroup;
  final String? photoB64;

  const ProfileData({
    this.name = '',
    this.age = '',
    this.gender = 'male',
    this.email = '',
    this.address = '',
    this.bloodGroup = '',
    this.photoB64,
  });
}
