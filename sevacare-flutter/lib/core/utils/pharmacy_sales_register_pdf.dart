import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'prescription_pdf_downloader_native.dart'
    if (dart.library.html) 'prescription_pdf_downloader_web.dart';
import '../../data/models/models.dart';

/// The downloadable, date-ranged sales/audit register — every line sold in the
/// window, one row each, for the accountant or a drug inspector to check
/// against the shelf. A4 portrait, unlike the 80mm receipt roll, since this is
/// meant to be filed or emailed, not handed across a counter.
class PharmacySalesRegisterPdf {
  static const _ink = PdfColor.fromInt(0xFF111827);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _rule = PdfColor.fromInt(0xFFBFC6D0);

  static String _rupees(int paise) => 'Rs ${(paise / 100).toStringAsFixed(2)}';

  static Future<Uint8List> generate({
    required String shopName,
    required String fromLabel,
    required String toLabel,
    required List<SalesRegisterLine> lines,
  }) async {
    final doc = pw.Document(title: 'Sales register $fromLabel to $toLabel', author: 'SevaCare');
    final bold = await PdfGoogleFonts.nunitoSansBold();
    final regular = await PdfGoogleFonts.nunitoSansRegular();

    final grossTotal = lines.fold<int>(0, (s, l) => s + l.grossPaise);
    final gstTotal = lines.fold<int>(0, (s, l) => s + l.gstPaise);
    final total = lines.fold<int>(0, (s, l) => s + l.totalPaise);

    pw.TableRow header() => pw.TableRow(children: [
          for (final h in const ['Date', 'Invoice', 'Item', 'Batch', 'Qty', 'Gross', 'GST', 'Total'])
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
              child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8, color: _ink)),
            ),
        ]);

    pw.TableRow row(SalesRegisterLine l) => pw.TableRow(children: [
          for (final v in [
            l.saleDate, l.invoiceNo, l.itemName, l.batchNo ?? '—', '${l.qtyBaseUnits}',
            _rupees(l.grossPaise), _rupees(l.gstPaise), _rupees(l.totalPaise),
          ])
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              child: pw.Text(v, style: pw.TextStyle(font: regular, fontSize: 8, color: _ink)),
            ),
        ]);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shopName, style: pw.TextStyle(font: bold, fontSize: 16, color: _ink)),
                pw.Text('Sales register · $fromLabel to $toLabel',
                    style: pw.TextStyle(font: regular, fontSize: 10, color: _muted)),
                pw.SizedBox(height: 10),
                pw.Divider(color: _rule, height: 1),
              ])
            : pw.SizedBox(),
        build: (ctx) => [
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3), 1: pw.FlexColumnWidth(1.3), 2: pw.FlexColumnWidth(2.6),
              3: pw.FlexColumnWidth(1.2), 4: pw.FlexColumnWidth(0.7), 5: pw.FlexColumnWidth(1),
              6: pw.FlexColumnWidth(1), 7: pw.FlexColumnWidth(1),
            },
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _rule, width: 0.5)),
            children: [header(), for (final l in lines) row(l)],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: _rule, height: 1),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Gross ${_rupees(grossTotal)} · GST ${_rupees(gstTotal)}',
                  style: pw.TextStyle(font: regular, fontSize: 9, color: _muted)),
              pw.Text('Total ${_rupees(total)}', style: pw.TextStyle(font: bold, fontSize: 13, color: _ink)),
            ]),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> download({
    required String shopName,
    required String fromLabel,
    required String toLabel,
    required List<SalesRegisterLine> lines,
  }) async {
    final bytes = await generate(shopName: shopName, fromLabel: fromLabel, toLabel: toLabel, lines: lines);
    await downloadPdf(bytes, 'Sales-Register-$fromLabel-to-$toLabel.pdf');
  }

  static Future<void> print({
    required String shopName,
    required String fromLabel,
    required String toLabel,
    required List<SalesRegisterLine> lines,
  }) async {
    final bytes = await generate(shopName: shopName, fromLabel: fromLabel, toLabel: toLabel, lines: lines);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Sales-Register-$fromLabel-to-$toLabel.pdf');
  }
}
