import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import 'app_avatar.dart';

/// Circular avatar with pencil-edit overlay. Tapping opens the image picker.
class ProfileAvatarPicker extends StatefulWidget {
  final String initials;
  final int hue;
  final double size;
  final ValueChanged<Uint8List?>? onImageChanged;

  const ProfileAvatarPicker({
    super.key,
    required this.initials,
    required this.hue,
    this.size = 80,
    this.onImageChanged,
  });

  @override
  State<ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  Uint8List? _imageBytes;

  Future<void> _pick() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() => _imageBytes = bytes);
        widget.onImageChanged?.call(bytes);
      }
    } catch (_) {
      // Permission denied or cancelled — silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final editSize = s * 0.3;

    return GestureDetector(
      onTap: _pick,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          children: [
            // Avatar or photo
            _imageBytes != null
                ? CircleAvatar(
                    radius: s / 2,
                    backgroundImage: MemoryImage(_imageBytes!),
                  )
                : AppAvatar(
                    initials: widget.initials,
                    size: s,
                    hue: widget.hue,
                  ),
            // Edit overlay — bottom right pencil icon
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: editSize,
                height: editSize,
                decoration: BoxDecoration(
                  color: SevaCareColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: SevaCareColors.primary.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit,
                  size: editSize * 0.55,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
