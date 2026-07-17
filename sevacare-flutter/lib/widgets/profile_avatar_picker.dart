import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'app_avatar.dart';

/// Circular avatar with pencil-edit overlay.
/// Pass [savedPhotoBytes] to display a previously persisted photo on load.
/// Tapping opens a bottom sheet with camera / gallery / remove options.
/// Calls [onImageChanged] with the new bytes whenever a photo is picked,
/// or null when the user removes it.
class ProfileAvatarPicker extends StatefulWidget {
  final String initials;
  final int hue;
  final double size;
  final Uint8List? savedPhotoBytes;
  final ValueChanged<Uint8List?>? onImageChanged;

  const ProfileAvatarPicker({
    super.key,
    required this.initials,
    required this.hue,
    this.size = 80,
    this.savedPhotoBytes,
    this.onImageChanged,
  });

  @override
  State<ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  // Null means "use savedPhotoBytes or initials avatar"
  Uint8List? _newImageBytes;

  Uint8List? get _displayBytes => _newImageBytes ?? widget.savedPhotoBytes;

  Future<void> _pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() => _newImageBytes = bytes);
        widget.onImageChanged?.call(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('Profile photo updated — tap Save Profile to keep it.'),
              ],
            ),
            backgroundColor: context.colors.mint,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: ${_friendlyError(e)}'),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission')) return 'permission denied';
    if (msg.contains('cancel')) return 'cancelled';
    return 'please try again';
  }

  Future<void> _showPicker() async {
    // Web: no camera support — go straight to gallery file picker
    if (kIsWeb) {
      await _pick(ImageSource.gallery);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(
        onCamera: () {
          Navigator.pop(ctx);
          _pick(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(ctx);
          _pick(ImageSource.gallery);
        },
        onRemove: _displayBytes != null
            ? () {
                Navigator.pop(ctx);
                setState(() => _newImageBytes = null);
                widget.onImageChanged?.call(null);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s        = widget.size;
    final editSize = s * 0.30;
    final bytes    = _displayBytes;

    return GestureDetector(
      onTap: _showPicker,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          children: [
            bytes != null
                ? CircleAvatar(
                    radius: s / 2,
                    backgroundImage: MemoryImage(bytes),
                  )
                : AppAvatar(
                    initials: widget.initials,
                    size: s,
                    hue: widget.hue,
                  ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: editSize,
                height: editSize,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: editSize * 0.52,
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

// ── Bottom sheet ───────────────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;

  const _PickerSheet({
    required this.onCamera,
    required this.onGallery,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E3F0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Update Profile Photo',
              style: AppTextStyles.sectionTitle(context.colors.text),
            ),
          ),
          const SizedBox(height: 16),
          _SheetOption(
            icon:  Icons.camera_alt_outlined,
            label: 'Take a photo',
            onTap: onCamera,
          ),
          _SheetOption(
            icon:  Icons.photo_library_outlined,
            label: 'Choose from gallery',
            onTap: onGallery,
          ),
          if (onRemove != null)
            _SheetOption(
              icon:  Icons.delete_outline,
              label: 'Remove photo',
              onTap: onRemove!,
              color: context.colors.danger,
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: AppTextStyles.label(context.colors.textMuted)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 16),
            Text(label, style: AppTextStyles.bodyText(c)),
          ],
        ),
      ),
    );
  }
}
