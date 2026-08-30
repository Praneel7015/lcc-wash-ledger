// Light, print-friendly wash report PDF — log-focused layout.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/constants.dart';
import '../models/visit.dart';

class ReportPdfInput {
  final DateTimeRange range;
  final List<Visit> visits;
  final Map<String, String> packageLabels;
  final RevenueBreakdown breakdown;

  const ReportPdfInput({
    required this.range,
    required this.visits,
    required this.packageLabels,
    required this.breakdown,
  });
}

class ReportPdfService {
  ReportPdfService._();

  static const _gold = PdfColor.fromInt(0xFFC9952A);
  static const _text = PdfColor.fromInt(0xFF1C1917);
  static const _muted = PdfColor.fromInt(0xFF5C5751);
  static const _stripe = PdfColor.fromInt(0xFFF5F4F2);
  static const _border = PdfColor.fromInt(0xFFE5E2DD);

  static const _dateFmt = 'd MMM yyyy';
  static const _rowDateFmt = 'dd/MM/yy';
  static const _timeFmt = 'HH:mm';
  static const _generatedFmt = 'd MMM yyyy, h:mm a';

  /// Rows per table chunk — keeps tables splittable across pages.
  static const _rowsPerChunk = 22;

  static String filenameFor(ReportPdfInput input) {
    final start = DateFormat('yyyy-MM-dd').format(input.range.start);
    final end = DateFormat('yyyy-MM-dd').format(input.range.end);
    return 'lcc-report-$start-$end.pdf';
  }

  static String rangeLabel(DateTimeRange range) =>
      '${DateFormat(_dateFmt).format(range.start)} – ${DateFormat(_dateFmt).format(range.end)}';

  static String packageLabel(String id, Map<String, String> labels) =>
      labels[id] ?? WashPackage.label(id);

  static Future<Uint8List> build(ReportPdfInput input) async {
    // Noto Sans covers ₹ (U+20B9) and – (U+2013) which the default
    // Helvetica/base14 fonts in the pdf package do not include.
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    pw.TextStyle baseStyle({
      double fontSize = 9,
      bool bold = false,
      PdfColor? color,
      double? letterSpacing,
    }) =>
        pw.TextStyle(
          font: bold ? fontBold : fontRegular,
          fontBold: fontBold,
          fontSize: fontSize,
          color: color ?? _text,
          letterSpacing: letterSpacing,
        );

    final generatedAt = DateTime.now();
    final generatedLabel = DateFormat(_generatedFmt).format(generatedAt);
    final range = rangeLabel(input.range);
    final breakdown = input.breakdown;
    final visits = input.visits;

    final summaryParts = <String>[
      '${visits.length} wash${visits.length == 1 ? '' : 'es'}',
      '₹${breakdown.total} total',
      'Cash ₹${breakdown.cash}',
      'UPI ₹${breakdown.upi}',
      if (breakdown.unknown > 0) 'Unknown ₹${breakdown.unknown}',
      'Pending ₹${breakdown.pending}',
    ];

    pw.Widget pageHeader() => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 4,
                height: 36,
                decoration: pw.BoxDecoration(
                  color: _gold,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'LUXURY ',
                            style: baseStyle(fontSize: 14, bold: true),
                          ),
                          pw.TextSpan(
                            text: 'CAR CARE',
                            style:
                                baseStyle(fontSize: 14, bold: true, color: _gold),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Wash Report · $range',
                      style: baseStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    pw.Widget pageFooter(pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'wash.sindhole.com  ·  Generated $generatedLabel  ·  Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: baseStyle(fontSize: 8, color: _muted),
          ),
        );

    pw.Widget summaryStrip() => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _stripe,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _border),
          ),
          child: pw.Text(
            summaryParts.join('  ·  '),
            style: baseStyle(fontSize: 10, bold: true),
          ),
        );

    pw.Widget cell(
      String text, {
      bool header = false,
      PdfColor? color,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: pw.Text(
            text,
            style: baseStyle(
              bold: header,
              color: color ?? _text,
            ),
          ),
        );

    pw.TableRow tableHeaderRow() => pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 1.5)),
          ),
          children: [
            'Date',
            'Time',
            'Plate',
            'Vehicle',
            'Package',
            'Amount',
            'Paid',
            'Paid by',
            'Phone',
          ]
              .map((h) => cell(h, header: true))
              .toList(),
        );

    pw.TableRow visitRow(Visit v, bool stripe) {
      final paidBy = PaymentMethod.reportLabel(
        paid: v.paid,
        method: v.paymentMethod,
      );
      return pw.TableRow(
        decoration: stripe
            ? const pw.BoxDecoration(color: _stripe)
            : const pw.BoxDecoration(),
        children: [
          DateFormat(_rowDateFmt).format(v.createdAt),
          DateFormat(_timeFmt).format(v.createdAt),
          formatIndianPlate(v.plate),
          VehicleType.label(v.vehicleType),
          packageLabel(v.packageId, input.packageLabels),
          '₹${v.amount}',
          v.paid ? 'Yes' : 'No',
          paidBy,
          v.phone ?? '',
        ].map((t) => cell(t)).toList(),
      );
    }

    pw.Widget visitTable(List<Visit> chunk, {required bool showHeader}) {
      final rows = <pw.TableRow>[];
      if (showHeader) rows.add(tableHeaderRow());
      for (var i = 0; i < chunk.length; i++) {
        rows.add(visitRow(chunk[i], i.isOdd));
      }
      return pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.1),
          1: const pw.FlexColumnWidth(0.9),
          2: const pw.FlexColumnWidth(1.6),
          3: const pw.FlexColumnWidth(1.3),
          4: const pw.FlexColumnWidth(2.2),
          5: const pw.FlexColumnWidth(0.9),
          6: const pw.FlexColumnWidth(0.7),
          7: const pw.FlexColumnWidth(1.0),
          8: const pw.FlexColumnWidth(1.3),
        },
        children: rows,
      );
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 44),
        header: (ctx) => pageHeader(),
        footer: (ctx) => pageFooter(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[
            summaryStrip(),
            pw.SizedBox(height: 14),
            pw.Text(
              'VISIT LOG',
              style: baseStyle(fontSize: 8, bold: true, color: _muted, letterSpacing: 1.2),
            ),
            pw.SizedBox(height: 6),
          ];

          for (var i = 0; i < visits.length; i += _rowsPerChunk) {
            final end = min(i + _rowsPerChunk, visits.length);
            final chunk = visits.sublist(i, end);
            widgets.add(visitTable(chunk, showHeader: true));
            if (end < visits.length) {
              widgets.add(pw.SizedBox(height: 8));
            }
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }
}
