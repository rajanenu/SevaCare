import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_colors.dart';
import 'doctor_photo.dart';
import 'staff_photo.dart';

// ── Patient Health Card ────────────────────────────────────────────────────────

class HealthCardWidget extends StatefulWidget {
  final String patientId;
  final String name;
  final String mobile;
  final String gender;
  final String age;
  final String bloodGroup;
  final String hospitalName;
  final Uint8List? photoBytes;
  final VoidCallback? onCameraPressed;

  const HealthCardWidget({
    super.key,
    required this.patientId,
    this.name = '',
    this.mobile = '',
    this.gender = '',
    this.age = '',
    this.bloodGroup = '',
    this.hospitalName = 'SevaCare',
    this.photoBytes,
    this.onCameraPressed,
  });

  @override
  State<HealthCardWidget> createState() => _HealthCardWidgetState();
}

class _HealthCardWidgetState extends State<HealthCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  String get _qrPayload {
    final parts = <String>[
      'SEVACARE:PATIENT',
      'ID:${widget.patientId}',
    ];
    if (widget.name.isNotEmpty) parts.add('NAME:${widget.name}');
    if (widget.mobile.isNotEmpty) parts.add('MOB:${widget.mobile}');
    if (widget.bloodGroup.isNotEmpty) parts.add('BG:${widget.bloodGroup}');
    return parts.join('|');
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _qrPayload));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) {
        return Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: SevaCareColors.primaryStrong.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3F39A8), Color(0xFF7C6FE0), Color(0xFF52C499)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _ShimmerPainter(_shimmer.value)),
                ),
                Positioned(
                  top: -30, right: -20,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40, left: 60,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.favorite_rounded,
                                      size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.hospitalName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.90),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    'HEALTH CARD',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              widget.name.isNotEmpty ? widget.name : 'Patient',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.patientId,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.70),
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                if (widget.bloodGroup.isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.bloodtype_outlined,
                                    value: widget.bloodGroup,
                                    iconColor: SevaCareColors.error,
                                  )
                                else
                                  _InfoChip(icon: Icons.bloodtype_outlined, value: 'Add BG', muted: true),
                                if (widget.gender.isNotEmpty)
                                  _InfoChip(icon: Icons.person_outline, value: _cap(widget.gender)),
                                if (widget.age.isNotEmpty)
                                  _InfoChip(icon: Icons.cake_outlined, value: '${widget.age}y'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Right: photo (if uploaded) or QR code + camera/share buttons
                      _CardMedia(
                        qrPayload: _qrPayload,
                        photoBytes: widget.photoBytes,
                        onCameraPressed: widget.onCameraPressed,
                        onSharePressed: _copyToClipboard,
                        qrEyeColor: const Color(0xFF3F39A8),
                        qrDataColor: const Color(0xFF1C1A34),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Doctor Card ────────────────────────────────────────────────────────────────

class DoctorCardWidget extends StatefulWidget {
  final String doctorId;
  final String name;
  final String mobile;
  final String specialty;
  final String hospitalName;
  final Uint8List? photoBytes;
  final VoidCallback? onCameraPressed;

  const DoctorCardWidget({
    super.key,
    required this.doctorId,
    this.name = '',
    this.mobile = '',
    this.specialty = '',
    this.hospitalName = 'SevaCare',
    this.photoBytes,
    this.onCameraPressed,
  });

  @override
  State<DoctorCardWidget> createState() => _DoctorCardWidgetState();
}

class _DoctorCardWidgetState extends State<DoctorCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  String get _qrPayload {
    final parts = <String>[
      'SEVACARE:DOCTOR',
      'ID:${widget.doctorId}',
    ];
    if (widget.name.isNotEmpty) parts.add('NAME:${widget.name}');
    if (widget.specialty.isNotEmpty) parts.add('SPEC:${widget.specialty}');
    if (widget.mobile.isNotEmpty) parts.add('MOB:${widget.mobile}');
    return parts.join('|');
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _qrPayload));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) {
        return Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF059669), Color(0xFF34D399)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _ShimmerPainter(_shimmer.value)),
                ),
                Positioned(
                  top: -30, right: -20,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40, left: 60,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.medical_services_rounded,
                                      size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.hospitalName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.90),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    'DOCTOR CARD',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              widget.name.isNotEmpty ? 'Dr. ${widget.name}' : 'Doctor',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.doctorId,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.70),
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                if (widget.specialty.isNotEmpty)
                                  _InfoChip(icon: Icons.local_hospital_outlined, value: widget.specialty),
                                if (widget.mobile.isNotEmpty)
                                  _InfoChip(icon: Icons.phone_outlined, value: widget.mobile),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Media slot shows the doctor's assigned photo instead
                      // of a QR code — a picked photo still takes precedence.
                      _CardMedia(
                        qrPayload: _qrPayload,
                        photoBytes: widget.photoBytes,
                        fallback: DoctorPhoto(
                          doctorId: widget.doctorId,
                          width: 96,
                          height: 96,
                        ),
                        onCameraPressed: widget.onCameraPressed,
                        onSharePressed: _copyToClipboard,
                        qrEyeColor: const Color(0xFF065F46),
                        qrDataColor: const Color(0xFF064E3B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Admin / Staff Card ─────────────────────────────────────────────────────────

class StaffCardWidget extends StatefulWidget {
  final String userId;
  final String name;
  final String mobile;
  final String hospitalName;
  final bool isStaff; // false → hospital admin styling/photo pool
  final Uint8List? photoBytes;
  final VoidCallback? onCameraPressed;

  const StaffCardWidget({
    super.key,
    required this.userId,
    this.name = '',
    this.mobile = '',
    this.hospitalName = 'SevaCare',
    this.isStaff = false,
    this.photoBytes,
    this.onCameraPressed,
  });

  @override
  State<StaffCardWidget> createState() => _StaffCardWidgetState();
}

class _StaffCardWidgetState extends State<StaffCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  List<Color> get _gradient => widget.isStaff
      ? const [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFF38BDF8)]
      : const [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF818CF8)];

  Color get _glow => widget.isStaff ? const Color(0xFF0284C7) : const Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) {
        return Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _glow.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _ShimmerPainter(_shimmer.value)),
                ),
                Positioned(
                  top: -30, right: -20,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40, left: 60,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.isStaff
                                        ? Icons.support_agent_rounded
                                        : Icons.manage_accounts_rounded,
                                    size: 12, color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.hospitalName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.90),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    widget.isStaff ? 'STAFF CARD' : 'ADMIN CARD',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              widget.name.isNotEmpty
                                  ? widget.name
                                  : (widget.isStaff ? 'Hospital Staff' : 'Hospital Admin'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.userId,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.70),
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                _InfoChip(
                                  icon: widget.isStaff
                                      ? Icons.badge_outlined
                                      : Icons.admin_panel_settings_outlined,
                                  value: widget.isStaff ? 'Patient Support' : 'Administration',
                                ),
                                if (widget.mobile.isNotEmpty)
                                  _InfoChip(icon: Icons.phone_outlined, value: widget.mobile),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Media slot: picked photo, else assigned stock photo
                      _CardMedia(
                        qrPayload: '',
                        photoBytes: widget.photoBytes,
                        fallback: StaffPhoto(
                          userId: widget.userId,
                          isStaff: widget.isStaff,
                          width: 96,
                          height: 96,
                        ),
                        onCameraPressed: widget.onCameraPressed,
                        qrEyeColor: const Color(0xFF312E81),
                        qrDataColor: const Color(0xFF1E1B4B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shared media slot: photo OR QR + camera/share overlay ─────────────────────

class _CardMedia extends StatelessWidget {
  final String qrPayload;
  final Uint8List? photoBytes;

  /// Shown instead of the QR code when no photo has been picked — used by
  /// doctor/admin/staff cards to display the user's assigned stock photo.
  final Widget? fallback;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onSharePressed;
  final Color qrEyeColor;
  final Color qrDataColor;

  const _CardMedia({
    required this.qrPayload,
    required this.qrEyeColor,
    required this.qrDataColor,
    this.photoBytes,
    this.fallback,
    this.onCameraPressed,
    this.onSharePressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoBytes != null;
    final showsQr = !hasPhoto && fallback == null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            // Photo or QR
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        photoBytes!,
                        fit: BoxFit.cover,
                        width: 96,
                        height: 96,
                      ),
                    )
                  : !showsQr
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: fallback,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(5),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 86,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: qrEyeColor,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: qrDataColor,
                            ),
                          ),
                        ),
            ),
            // Camera button (bottom-right corner)
            if (onCameraPressed != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onCameraPressed,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: SevaCareColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: SevaCareColors.primary.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          showsQr ? 'Scan / Share' : 'Photo',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.65),
            letterSpacing: 0.4,
          ),
        ),
        if (showsQr && onSharePressed != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onSharePressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 11, color: Colors.white.withValues(alpha: 0.90)),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Info chip ──────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool muted;
  final Color? iconColor;

  const _InfoChip({required this.icon, required this.value, this.muted = false, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.10 : 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: muted ? 0.15 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: muted
                ? Colors.white.withValues(alpha: 0.55)
                : (iconColor ?? Colors.white.withValues(alpha: 0.90)),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: muted ? 0.55 : 0.90),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer sweep painter ──────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final double t;
  const _ShimmerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * 0.4 + t * size.width * 1.8;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x - 60, 0, 120, size.height));

    final angle = math.pi / 6;
    final path = Path()
      ..moveTo(x - 60 * math.cos(angle), 0)
      ..lineTo(x + 60 * math.cos(angle), 0)
      ..lineTo(x + 60 * math.cos(angle), size.height)
      ..lineTo(x - 60 * math.cos(angle), size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t;
}
