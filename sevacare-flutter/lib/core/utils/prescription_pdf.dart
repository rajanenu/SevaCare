import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/models.dart';

class PrescriptionPdfService {
  static const _primaryColor = PdfColor.fromInt(0xFF1A73E8);
  static const _accentColor = PdfColor.fromInt(0xFF0D47A1);
  static const _mintColor = PdfColor.fromInt(0xFF00897B);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F7FA);
  static const _borderColor = PdfColor.fromInt(0xFFDDE3EA);
  static const _textMuted = PdfColor.fromInt(0xFF6B7280);
  static const _textDark = PdfColor.fromInt(0xFF111827);
  static const _white = PdfColors.white;

  static Future<Uint8List> generate({
    required String hospitalName,
    required PrescriptionDetailView rx,
  }) async {
    final doc = pw.Document(
      title: 'Prescription ${rx.prescriptionPublicId}',
      author: 'SevaCare',
    );

    final boldFont = await PdfGoogleFonts.nunitoSansBold();
    final regularFont = await PdfGoogleFonts.nunitoSansRegular();
    final semiBoldFont = await PdfGoogleFonts.nunitoSansSemiBold();
    final italicFont = await PdfGoogleFonts.nunitoSansItalic();

    final rxLabel = _rxLabel(rx.prescriptionPublicId);
    final doctorDisplay = 'Dr. ${rx.doctorName}';
    final specialty = rx.doctorSpecialty ?? 'General Physician';
    final patientDisplay = rx.patientName ?? 'Patient';
    final issuedDate = _formatDate(rx.issuedOn);
    final validDate = rx.validUntil != null ? _formatDate(rx.validUntil!) : 'N/A';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(hospitalName, doctorDisplay, specialty, boldFont, semiBoldFont, regularFont),
        footer: (ctx) => _buildFooter(rxLabel, regularFont, italicFont, ctx),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _buildMetaRow(rxLabel, patientDisplay, issuedDate, validDate, semiBoldFont, regularFont, boldFont),
          pw.SizedBox(height: 20),
          _buildMedicinesTable(rx.medicines, boldFont, semiBoldFont, regularFont),
          if (rx.notes != null && rx.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildNotes(rx.notes!, semiBoldFont, regularFont),
          ],
          pw.SizedBox(height: 28),
          _buildSignature(doctorDisplay, specialty, boldFont, semiBoldFont, regularFont),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(
    String hospitalName,
    String doctor,
    String specialty,
    pw.Font boldFont,
    pw.Font semiBoldFont,
    pw.Font regularFont,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  hospitalName,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 22,
                    color: _white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0x33FFFFFF),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(99)),
                  ),
                  child: pw.Text(
                    'MEDICAL PRESCRIPTION',
                    style: pw.TextStyle(
                      font: semiBoldFont,
                      fontSize: 9,
                      color: _white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                doctor,
                style: pw.TextStyle(font: boldFont, fontSize: 14, color: _white),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                specialty,
                style: pw.TextStyle(font: regularFont, fontSize: 11, color: PdfColor.fromInt(0xFFBBDEFB)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaRow(
    String rxLabel,
    String patient,
    String issuedDate,
    String validDate,
    pw.Font semiBoldFont,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _borderColor),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _metaCell('Prescription ID', rxLabel, semiBoldFont, regularFont, boldFont),
          _metaCell('Patient', patient, semiBoldFont, regularFont, boldFont),
          _metaCell('Issue Date', issuedDate, semiBoldFont, regularFont, boldFont),
          _metaCell('Valid Until', validDate, semiBoldFont, regularFont, boldFont),
        ],
      ),
    );
  }

  static pw.Widget _metaCell(String label, String value, pw.Font semiBoldFont, pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: semiBoldFont, fontSize: 8, color: _textMuted, letterSpacing: 0.5)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 12, color: _textDark)),
      ],
    );
  }

  static pw.Widget _buildMedicinesTable(
    List<MedicineView> medicines,
    pw.Font boldFont,
    pw.Font semiBoldFont,
    pw.Font regularFont,
  ) {
    const headerBg = _accentColor;
    const rowAlt = PdfColor.fromInt(0xFFF0F4FF);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 18,
              decoration: const pw.BoxDecoration(color: _mintColor, borderRadius: pw.BorderRadius.all(pw.Radius.circular(2))),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Prescribed Medicines',
              style: pw.TextStyle(font: boldFont, fontSize: 13, color: _textDark),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Medicine Name', 'Strength', 'Frequency', 'Duration', 'Instructions'],
          data: medicines.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return [
              '${i + 1}',
              m.name,
              m.strength.isNotEmpty ? m.strength : '—',
              m.frequency.isNotEmpty ? m.frequency : '—',
              m.duration.isNotEmpty ? m.duration : '—',
              (m.instructions != null && m.instructions!.isNotEmpty) ? m.instructions! : '—',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: _white),
          headerDecoration: const pw.BoxDecoration(color: headerBg),
          cellStyle: pw.TextStyle(font: regularFont, fontSize: 9.5, color: _textDark),
          rowDecoration: const pw.BoxDecoration(color: _white),
          oddRowDecoration: const pw.BoxDecoration(color: rowAlt),
          border: pw.TableBorder.all(color: _borderColor, width: 0.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(3),
          },
        ),
      ],
    );
  }

  static pw.Widget _buildNotes(String notes, pw.Font semiBoldFont, pw.Font regularFont) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: _mintColor, width: 3)),
        color: PdfColor.fromInt(0xFFE8F5E9),
        borderRadius: const pw.BorderRadius.only(
          topRight: pw.Radius.circular(6),
          bottomRight: pw.Radius.circular(6),
        ),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Doctor\'s Notes', style: pw.TextStyle(font: semiBoldFont, fontSize: 10, color: _mintColor)),
          pw.SizedBox(height: 5),
          pw.Text(notes, style: pw.TextStyle(font: regularFont, fontSize: 10, color: _textDark)),
        ],
      ),
    );
  }

  static pw.Widget _buildSignature(
    String doctor,
    String specialty,
    pw.Font boldFont,
    pw.Font semiBoldFont,
    pw.Font regularFont,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 1)),
          ),
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(doctor, style: pw.TextStyle(font: boldFont, fontSize: 11, color: _textDark)),
              pw.SizedBox(height: 2),
              pw.Text(specialty, style: pw.TextStyle(font: regularFont, fontSize: 9.5, color: _textMuted)),
              pw.SizedBox(height: 2),
              pw.Text('Authorised Signatory', style: pw.TextStyle(font: regularFont, fontSize: 8, color: _textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(String rxLabel, pw.Font regularFont, pw.Font italicFont, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Issued digitally via SevaCare  •  $rxLabel',
            style: pw.TextStyle(font: italicFont, fontSize: 8, color: _textMuted),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: regularFont, fontSize: 8, color: _textMuted),
          ),
        ],
      ),
    );
  }

  static Future<void> download({
    required String hospitalName,
    required PrescriptionDetailView rx,
  }) async {
    final bytes = await generate(hospitalName: hospitalName, rx: rx);
    final filename = 'prescription_${rx.prescriptionPublicId}.pdf';
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _rxLabel(String id) {
    final clean = id.replaceAll('-', '').toUpperCase();
    final suffix = clean.length > 8 ? clean.substring(clean.length - 8) : clean;
    return 'RX-$suffix';
  }

  static String _formatDate(String raw) {
    try {
      final parts = raw.split('-');
      if (parts.length == 3) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final m = int.tryParse(parts[1]);
        if (m != null && m >= 1 && m <= 12) {
          return '${parts[2]} ${months[m - 1]} ${parts[0]}';
        }
      }
    } catch (_) {}
    return raw;
  }
}
