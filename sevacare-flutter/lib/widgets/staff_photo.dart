import 'package:flutter/material.dart';
import '../core/utils/staff_photo.dart';

/// Displays the stock photo assigned to a hospital admin or support staff
/// member (see [adminPhotoAsset] / [staffPhotoAsset]).
class StaffPhoto extends StatelessWidget {
  final String userId;
  final bool isStaff; // false → hospital admin pool
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Alignment alignment;

  const StaffPhoto({
    super.key,
    required this.userId,
    this.isStaff = false,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    // Source photos are portrait shots with the face in the upper portion —
    // bias the crop toward the top so square/landscape boxes keep the face.
    this.alignment = const Alignment(0, -0.8),
  });

  factory StaffPhoto.circle({
    Key? key,
    required String userId,
    required double size,
    bool isStaff = false,
  }) {
    return StaffPhoto(
      key: key,
      userId: userId,
      isStaff: isStaff,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unknown identity (e.g. the split-second after sign-out while the profile
    // screen is still mounted) → neutral avatar instead of the first pooled
    // stock photo, which is a real face and caused a wrong-photo flash on logout.
    if (userId.isEmpty) {
      final side = (width ?? height ?? 48);
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: borderRadius,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.person, color: const Color(0xFF94A3B8), size: side * 0.5),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        isStaff ? staffPhotoAsset(userId) : adminPhotoAsset(userId),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
      ),
    );
  }
}
