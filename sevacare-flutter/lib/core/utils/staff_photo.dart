/// Bundled stock headshots for hospital admins and support staff, mirroring
/// the doctor photo approach (see doctor_photo.dart). Deterministically
/// assigned per user (same admin/staff always gets the same photo) by hashing
/// the user's public ID.
const List<String> adminPhotoAssets = [
  'assets/images/staff_photos/admin_m1.jpg',
  'assets/images/staff_photos/admin_f1.jpg',
  'assets/images/staff_photos/admin_m2.jpg',
  'assets/images/staff_photos/admin_f2.jpg',
];

const List<String> staffPhotoAssets = [
  'assets/images/staff_photos/staff_f1.jpg',
  'assets/images/staff_photos/staff_m1.jpg',
  'assets/images/staff_photos/staff_f2.jpg',
  'assets/images/staff_photos/staff_m2.jpg',
];

/// Gender-correct overrides for known demo users (tenant T-1013), keyed by
/// admin/staff public ID — same pattern as _doctorPhotoOverrides. Admins and
/// staff share the A- ID space (one admin_user table, split by user_type), so
/// one map covers both. Extend this map when new demo users are seeded.
const Map<String, String> _staffPhotoOverrides = {
  'A-1076': 'assets/images/staff_photos/admin_m1.jpg', // Generic Admin
  'A-1078': 'assets/images/staff_photos/admin_f1.jpg', // Lakshmi Kishore
  'A-1080': 'assets/images/staff_photos/admin_f2.jpg', // Lakshmi Kishore 2
  'A-1085': 'assets/images/staff_photos/staff_m1.jpg', // Staff Raju
};

String adminPhotoAsset(String publicId) => _assetFor(publicId, adminPhotoAssets);

String staffPhotoAsset(String publicId) => _assetFor(publicId, staffPhotoAssets);

String _assetFor(String publicId, List<String> pool) {
  final override = _staffPhotoOverrides[publicId];
  if (override != null) return override;
  if (publicId.isEmpty) return pool.first;
  final hash = publicId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return pool[hash % pool.length];
}
