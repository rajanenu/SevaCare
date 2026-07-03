/// Bundled stock doctor headshots used until a hospital uploads real photos.
/// Deterministically assigned per doctor (same doctor always gets the same
/// photo) by hashing the doctor's public ID — not gender-matched, since the
/// doctor record has no gender field.
const List<String> doctorPhotoAssets = [
  'assets/images/doctor_photos/doctor_f1.jpg',
  'assets/images/doctor_photos/doctor_f2.jpg',
  'assets/images/doctor_photos/doctor_f3.jpg',
  'assets/images/doctor_photos/doctor_f4.jpg',
  'assets/images/doctor_photos/doctor_f5.jpg',
  'assets/images/doctor_photos/doctor_m1.jpg',
  'assets/images/doctor_photos/doctor_m2.jpg',
  'assets/images/doctor_photos/doctor_m3.jpg',
  'assets/images/doctor_photos/doctor_m4.jpg',
  'assets/images/doctor_photos/doctor_m5.jpg',
];

/// Gender-correct overrides for known demo doctors, since the doctor record
/// has no gender field and the hash fallback below can't tell male from
/// female. Add an entry here whenever a specific doctor's assigned photo
/// needs to be pinned rather than left to the hash.
const Map<String, String> _doctorPhotoOverrides = {
  'D-1002': 'assets/images/doctor_photos/doctor_f1.jpg', // Ananya Krishnan
  'D-1003': 'assets/images/doctor_photos/doctor_m1.jpg', // Arjun Varma
  'D-1004': 'assets/images/doctor_photos/doctor_f2.jpg', // Priya Sharma
  'D-1005': 'assets/images/doctor_photos/doctor_m2.jpg', // Sanjay Patel
  'D-1006': 'assets/images/doctor_photos/doctor_f3.jpg', // Kavitha Nair
  'D-1007': 'assets/images/doctor_photos/doctor_m3.jpg', // Suresh Dental
  'D-1008': 'assets/images/doctor_photos/doctor_f4.jpg', // Meena Pediatrics
  'D-1009': 'assets/images/doctor_photos/doctor_m4.jpg', // Rajasekhar
};

String doctorPhotoAsset(String doctorPublicId) {
  final override = _doctorPhotoOverrides[doctorPublicId];
  if (override != null) return override;
  if (doctorPublicId.isEmpty) return doctorPhotoAssets.first;
  final hash = doctorPublicId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return doctorPhotoAssets[hash % doctorPhotoAssets.length];
}
