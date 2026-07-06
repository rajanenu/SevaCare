import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/doctor_photo.dart';
import '../providers/app_state.dart';

/// Displays the doctor's uploaded photo when one has synced to the backend,
/// falling back to the bundled stock photo assigned via [doctorPhotoAsset].
class DoctorPhoto extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // When identity is unknown (e.g. the split-second after sign-out while the
    // profile screen is still mounted), render a neutral avatar instead of the
    // first pooled stock photo — that pool photo is a real person's face and
    // caused a jarring "someone else's photo" flash on logout.
    if (doctorId.isEmpty) {
      return _NeutralAvatar(width: width, height: height, borderRadius: borderRadius);
    }
    final uploaded = ref.watch(doctorPhotoProvider(doctorId)).valueOrNull;
    return ClipRRect(
      borderRadius: borderRadius,
      child: uploaded != null
          ? Image.memory(
              uploaded,
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
              gaplessPlayback: true,
            )
          : Image.asset(
              doctorPhotoAsset(doctorId),
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
            ),
    );
  }
}

/// Neutral placeholder shown when no identity is available yet.
class _NeutralAvatar extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const _NeutralAvatar({this.width, this.height, this.borderRadius = BorderRadius.zero});

  @override
  Widget build(BuildContext context) {
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
}
