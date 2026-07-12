import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'prescription_pdf_downloader_native.dart'
    if (dart.library.html) 'prescription_pdf_downloader_web.dart';
import '../../data/models/models.dart';

/// The counter receipt as a thermal-printer-friendly PDF. Two exits: print it to
/// the shop's printer ({@link printReceipt}) or hand the customer a file/share
/// sheet ({@link downloadReceipt}). One 80mm-wide roll format, because that is
/// what a medical store's printer is.
class PharmacyReceiptPdf {
  static const _ink = PdfColor.fromInt(0xFF111827);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _rule = PdfColor.fromInt(0xFFBFC6D0);

  static String _rupees(int paise) => 'Rs ${(paise / 100).toStringAsFixed(2)}';

  static Future<Uint8List> generate({
    required String shopName,
    required SaleReceipt receipt,
    String? customerName,
    String? customerMobile,
  }) async {
    final doc = pw.Document(title: 'Receipt ${receipt.invoiceNo}', author: 'SevaCare');
    final bold = await PdfGoogleFonts.nunitoSansBold();
    final regular = await PdfGoogleFonts.nunitoSansRegular();

    // 80mm roll; height grows with content.
    final format = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
        marginAll: 6 * PdfPageFormat.mm);

    pw.Widget kv(String k, String v, {bool strong = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: pw.TextStyle(font: regular, fontSize: 9, color: _muted)),
            pw.Text(v, style: pw.TextStyle(font: strong ? bold : regular, fontSize: strong ? 11 : 9, color: _ink)),
          ],
        );

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Center(child: pw.Text(shopName, style: pw.TextStyle(font: bold, fontSize: 13, color: _ink))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text('Tax Invoice', style: pw.TextStyle(font: regular, fontSize: 8, color: _muted))),
            pw.SizedBox(height: 6),
            kv('Invoice', receipt.invoiceNo),
            if (customerName != null && customerName.trim().isNotEmpty) kv('Customer', customerName.trim()),
            if (customerMobile != null && customerMobile.trim().isNotEmpty) kv('Mobile', customerMobile.trim()),
            pw.SizedBox(height: 6),
            pw.Divider(color: _rule, height: 1),
            pw.SizedBox(height: 4),
            for (final l in receipt.lines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                  pw.Text(l.brandName, style: pw.TextStyle(font: bold, fontSize: 9, color: _ink)),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('${l.qtyBaseUnits} x ${_rupees(l.mrpPaise)}',
                        style: pw.TextStyle(font: regular, fontSize: 8, color: _muted)),
                    pw.Text(_rupees(l.grossPaise), style: pw.TextStyle(font: regular, fontSize: 9, color: _ink)),
                  ]),
                ]),
              ),
            pw.SizedBox(height: 4),
            pw.Divider(color: _rule, height: 1),
            pw.SizedBox(height: 4),
            kv('Taxable', _rupees(receipt.taxablePaise)),
            kv('GST', _rupees(receipt.gstPaise)),
            if (receipt.discountPaise > 0) kv('Discount', '- ${_rupees(receipt.discountPaise)}'),
            pw.SizedBox(height: 3),
            kv('TOTAL', _rupees(receipt.totalPaise), strong: true),
            kv('Paid via', receipt.paymentMode),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('Get well soon. Keep this receipt for returns.',
                style: pw.TextStyle(font: regular, fontSize: 7, color: _muted))),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> printReceipt({
    required String shopName,
    required SaleReceipt receipt,
    String? customerName,
    String? customerMobile,
  }) async {
    final bytes = await generate(
        shopName: shopName, receipt: receipt, customerName: customerName, customerMobile: customerMobile);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Receipt ${receipt.invoiceNo}');
  }

  static Future<void> downloadReceipt({
    required String shopName,
    required SaleReceipt receipt,
    String? customerName,
    String? customerMobile,
  }) async {
    final bytes = await generate(
        shopName: shopName, receipt: receipt, customerName: customerName, customerMobile: customerMobile);
    await downloadPdf(bytes, 'Receipt-${receipt.invoiceNo}.pdf');
  }
}
