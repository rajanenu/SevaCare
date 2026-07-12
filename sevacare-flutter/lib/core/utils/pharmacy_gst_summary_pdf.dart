import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'prescription_pdf_downloader_native.dart'
    if (dart.library.html) 'prescription_pdf_downloader_web.dart';
import '../../data/models/models.dart';

/// The GST slab summary — one row per rate (0/5/12/18%), taxable + GST +
/// gross for a date range. This is the sheet the accountant transcribes at
/// filing time, so it stays deliberately plain: rates, four numbers, totals.
class PharmacyGstSummaryPdf {
  static const _ink = PdfColor.fromInt(0xFF111827);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _rule = PdfColor.fromInt(0xFFBFC6D0);

  static String _rupees(int paise) => 'Rs ${(paise / 100).toStringAsFixed(2)}';
  static String _rate(int bp) => '${(bp / 100).toStringAsFixed(bp % 100 == 0 ? 0 : 2)}%';

  static Future<Uint8List> generate({
    required String shopName,
    required String fromLabel,
    required String toLabel,
    required List<GstSlabTotal> slabs,
  }) async {
    final doc = pw.Document(title: 'GST summary $fromLabel to $toLabel', author: 'SevaCare');
    final bold = await PdfGoogleFonts.nunitoSansBold();
    final regular = await PdfGoogleFonts.nunitoSansRegular();

    final taxableTotal = slabs.fold<int>(0, (s, l) => s + l.taxablePaise);
    final gstTotal = slabs.fold<int>(0, (s, l) => s + l.gstPaise);
    final grossTotal = slabs.fold<int>(0, (s, l) => s + l.grossPaise);

    pw.Widget cell(String v, {bool head = false, bool end = true}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: pw.Align(
            alignment: end ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: pw.Text(v,
                style: pw.TextStyle(font: head ? bold : regular, fontSize: 9.5, color: _ink)),
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(shopName, style: pw.TextStyle(font: bold, fontSize: 16, color: _ink)),
          pw.Text('GST summary · $fromLabel to $toLabel',
              style: pw.TextStyle(font: regular, fontSize: 10, color: _muted)),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _rule, width: 0.5)),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(children: [
                cell('GST rate', head: true, end: false),
                cell('Lines', head: true),
                cell('Taxable', head: true),
                cell('GST', head: true),
                cell('Gross', head: true),
              ]),
              for (final s in slabs)
                pw.TableRow(children: [
                  cell(_rate(s.gstRateBp), end: false),
                  cell('${s.lineCount}'),
                  cell(_rupees(s.taxablePaise)),
                  cell(_rupees(s.gstPaise)),
                  cell(_rupees(s.grossPaise)),
                ]),
              pw.TableRow(children: [
                cell('Total', head: true, end: false),
                cell(''),
                cell(_rupees(taxableTotal), head: true),
                cell(_rupees(gstTotal), head: true),
                cell(_rupees(grossTotal), head: true),
              ]),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Amounts derived from completed sales only; voided bills are excluded. '
            'MRP is GST-inclusive; taxable values are backed out per line at sale time.',
            style: pw.TextStyle(font: regular, fontSize: 8, color: _muted),
          ),
        ]),
      ),
    );
    return doc.save();
  }

  static Future<void> download({
    required String shopName,
    required String fromLabel,
    required String toLabel,
    required List<GstSlabTotal> slabs,
  }) async {
    final bytes = await generate(shopName: shopName, fromLabel: fromLabel, toLabel: toLabel, slabs: slabs);
    await downloadPdf(bytes, 'GST-Summary-$fromLabel-to-$toLabel.pdf');
  }
}
