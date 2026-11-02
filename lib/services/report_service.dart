import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters.dart';
import '../core/registration_rules.dart';
import '../models/models.dart';

/// Everything the post-event report needs, computed once.
class EventReportData {
  EventReportData({
    required this.event,
    required this.registrations,
    required this.feedback,
    required this.budget,
    required this.orders,
  });

  final Event event;
  final List<Registration> registrations;
  final List<EventFeedback> feedback;
  final List<BudgetLine> budget;
  final List<VendorOrder> orders;

  int get registered => registrations
      .where(
        (r) =>
            r.status == RegistrationStatus.registered ||
            r.status == RegistrationStatus.attended,
      )
      .length;
  int get attended =>
      registrations.where((r) => r.status == RegistrationStatus.attended).length;
  int get walkIns => registrations.where((r) => r.isWalkIn).length;
  int get waitlisted =>
      registrations.where((r) => r.status == RegistrationStatus.waitlisted).length;
  int get cancelled =>
      registrations.where((r) => r.status == RegistrationStatus.cancelled).length;
  double get noShowRate =>
      RegistrationRules.noShowRate(registered: registered, attended: attended);

  double get averageRating {
    if (feedback.isEmpty) return 0;
    return feedback.fold<int>(0, (s, f) => s + f.eventRating) / feedback.length;
  }

  double get plannedBudget => budget.fold(0, (s, b) => s + b.planned);
  double get actualBudget => budget.fold(0, (s, b) => s + b.actual);

  double get vendorRevenue => orders
      .where((o) => o.status != OrderStatus.cancelled)
      .fold(0, (s, o) => s + o.total);

  /// Arrivals bucketed into 15-minute slots relative to the event start.
  /// Key = minutes offset from start (negative = early), value = count.
  Map<int, int> get arrivalsByQuarterHour {
    final buckets = <int, int>{};
    for (final r in registrations) {
      final at = r.checkedInAt;
      if (at == null) continue;
      final offset = at.difference(event.startTime).inMinutes;
      final bucket = (offset / 15).floor() * 15;
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    return Map.fromEntries(
      buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  int? get peakArrivalMinute {
    final b = arrivalsByQuarterHour;
    if (b.isEmpty) return null;
    return b.entries.reduce((a, c) => c.value > a.value ? c : a).key;
  }

  /// 1–5 star distribution.
  List<int> get ratingDistribution {
    final dist = List<int>.filled(5, 0);
    for (final f in feedback) {
      if (f.eventRating >= 1 && f.eventRating <= 5) dist[f.eventRating - 1]++;
    }
    return dist;
  }
}

/// Builds the Student Affairs post-event report as a PDF.
class ReportService {
  Future<Uint8List> buildPdf(EventReportData d) async {
    final doc = pw.Document();
    final indigo = PdfColor.fromHex('#4F46E5');
    final midnight = PdfColor.fromHex('#1E1B4B');
    final grey = PdfColor.fromHex('#6B7280');

    pw.Widget stat(String label, String value) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: midnight,
                ),
              ),
              pw.Text(label, style: pw.TextStyle(fontSize: 9, color: grey)),
            ],
          ),
        );

    pw.Widget heading(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
          child: pw.Text(
            t,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: indigo,
            ),
          ),
        );

    final e = d.event;
    final arrivals = d.arrivalsByQuarterHour;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'UniEvent • Post-Event Report • Page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: grey),
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [PdfColor.fromHex('#6D28D9'), PdfColor.fromHex('#3B82F6')],
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'UniEvent — Post-Event Report',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  e.title,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${e.organiserName} • ${Fmt.date(e.startTime)} • ${e.venue}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Prepared for Student Affairs on ${Fmt.date(DateTime.now())}.',
            style: pw.TextStyle(fontSize: 9, color: grey),
          ),
          heading('Attendance'),
          pw.Row(
            children: [
              pw.Expanded(child: stat('Capacity', '${e.capacity}')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: stat('Registered', '${d.registered}')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: stat('Attended', '${d.attended}')),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: stat('No-show rate', Fmt.percent(d.noShowRate)),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: stat('Walk-ins', '${d.walkIns}')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: stat('Still waitlisted', '${d.waitlisted}')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: stat('Cancelled', '${d.cancelled}')),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: stat(
                  'Peak arrival',
                  d.peakArrivalMinute == null
                      ? '—'
                      : _offsetLabel(d.peakArrivalMinute!),
                ),
              ),
            ],
          ),
          if (arrivals.isNotEmpty) ...[
            heading('Arrivals over time (15-minute slots)'),
            pw.TableHelper.fromTextArray(
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Slot', 'Arrivals', ''],
              data: arrivals.entries
                  .map(
                    (a) => [
                      _offsetLabel(a.key),
                      '${a.value}',
                      '█' * a.value.clamp(0, 40).toInt(),
                    ],
                  )
                  .toList(),
            ),
          ],
          heading('Participant feedback'),
          pw.Text(
            d.feedback.isEmpty
                ? 'No feedback submitted yet.'
                : 'Average rating ${d.averageRating.toStringAsFixed(1)} / 5 '
                    'from ${d.feedback.length} responses.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (d.feedback.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Stars', 'Responses'],
              data: List.generate(
                5,
                (i) => ['${5 - i} ★', '${d.ratingDistribution[4 - i]}'],
              ),
            ),
            ...d.feedback
                .where((f) => f.comment.trim().isNotEmpty)
                .take(10)
                .map(
                  (f) => pw.Bullet(
                    text: '"${f.comment.trim()}" — ${f.eventRating}★',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
          ],
          heading('Budget summary'),
          pw.Row(
            children: [
              pw.Expanded(child: stat('Planned', Fmt.rm(d.plannedBudget))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: stat('Actual', Fmt.rm(d.actualBudget))),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: stat(
                  'Variance',
                  Fmt.rm(d.plannedBudget - d.actualBudget),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: stat('Vendor revenue', Fmt.rm(d.vendorRevenue))),
            ],
          ),
          if (d.budget.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Category', 'Description', 'Planned', 'Actual'],
              data: d.budget
                  .map(
                    (b) => [
                      b.category,
                      b.description,
                      Fmt.rm(b.planned),
                      Fmt.rm(b.actual),
                    ],
                  )
                  .toList(),
            ),
          ],
          heading('Event performance'),
          pw.Bullet(
            text: 'Fill rate: ${e.capacity == 0 ? '—' : Fmt.percent(d.registered / e.capacity * 100)} of capacity registered.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Bullet(
            text: 'Show-up rate: ${Fmt.percent(100 - d.noShowRate)} of registered students attended.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Bullet(
            text: 'Vendor orders: ${d.orders.where((o) => o.status != OrderStatus.cancelled).length} completed, ${d.orders.where((o) => o.status == OrderStatus.cancelled).length} cancelled.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Opens the system share / print sheet with the generated PDF.
  Future<void> sharePdf(EventReportData d) async {
    final bytes = await buildPdf(d);
    final safeTitle = d.event.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    await Printing.sharePdf(bytes: bytes, filename: 'UniEvent_Report_$safeTitle.pdf');
  }

  String _offsetLabel(int minutes) {
    final sign = minutes < 0 ? '−' : '+';
    final abs = minutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    final body = h > 0 ? '${h}h${m > 0 ? ' ${m}m' : ''}' : '${m}m';
    return minutes == 0 ? 'Start' : '$sign$body';
  }
}
