import 'package:flutter/material.dart';
import '../core/utils/doctor_photo.dart';

/// Displays the stock photo assigned to a doctor (see [doctorPhotoAsset]).
class DoctorPhoto extends StatelessWidget {
  final String doctorId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Alignment alignment;

  const DoctorPhoto({
    super.key,
    required this.doctorId,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    // Source photos are portrait headshots with the face in the upper
    // portion — biasing the crop toward the top keeps the face visible
    // instead of centering on the neck/shoulders when the display box is
    // wider/shorter than the source image.
    this.alignment = const Alignment(0, -0.9),
  });

  factory DoctorPhoto.circle({Key? key, required String doctorId, required double size}) {
    return DoctorPhoto(
      key: key,
      doctorId: doctorId,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        doctorPhotoAsset(doctorId),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
      ),
    );
  }
}
