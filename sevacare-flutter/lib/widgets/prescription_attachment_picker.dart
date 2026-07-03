import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class PickedPrescriptionFile {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const PickedPrescriptionFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

/// Lets a patient (or IP-Staff booking on their behalf) attach photos of
/// existing prescriptions at booking time, so the doctor can review them
/// before/during the consultation.
class PrescriptionAttachmentPicker extends StatefulWidget {
  final ValueChanged<List<PickedPrescriptionFile>> onChanged;

  const PrescriptionAttachmentPicker({super.key, required this.onChanged});

  @override
  State<PrescriptionAttachmentPicker> createState() => _PrescriptionAttachmentPickerState();
}

class _PrescriptionAttachmentPickerState extends State<PrescriptionAttachmentPicker> {
  final List<PickedPrescriptionFile> _files = [];
  static const int _maxFiles = 5;

  Future<void> _showPickerSheet() async {
    if (_files.length >= _maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can attach up to $_maxFiles prescription photos.'),
          backgroundColor: SevaCareColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sheetOption(ctx, Icons.camera_alt_outlined, 'Camera', ImageSource.camera),
              _sheetOption(ctx, Icons.photo_library_outlined, 'Gallery', ImageSource.gallery),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Widget _sheetOption(BuildContext ctx, IconData icon, String label, ImageSource source) {
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(source),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: SevaCareColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: SevaCareColors.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.label(SevaCareColors.text)),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      if (mounted) {
        setState(() => _files.add(PickedPrescriptionFile(
              fileName: picked.name,
              mimeType: mimeType,
              bytes: bytes,
            )));
        widget.onChanged(List.unmodifiable(_files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not attach photo. Please try again.'),
            backgroundColor: SevaCareColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _remove(int index) {
    setState(() => _files.removeAt(index));
    widget.onChanged(List.unmodifiable(_files));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined, size: 16, color: SevaCareColors.primary),
            const SizedBox(width: 6),
            Text('Have old prescriptions? Add them',
                style: AppTextStyles.label(SevaCareColors.text).copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _files.isEmpty
                  ? Text(
                      'No prescriptions attached yet',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    )
                  : SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _files.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _files[i].bytes,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: -6,
                              top: -6,
                              child: GestureDetector(
                                onTap: () => _remove(i),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: SevaCareColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _showPickerSheet,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SevaCareColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: SevaCareColors.primary),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: SevaCareColors.primary, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
