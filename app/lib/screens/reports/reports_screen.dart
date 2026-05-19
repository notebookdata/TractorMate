import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:pdf/src/widgets/table_helper.dart' as pw_table;
import 'package:path_provider/path_provider.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'month';
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports / ವರದಿಗಳು')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Period / ಅವಧಿ ಆಯ್ಕೆ ಮಾಡಿ',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final p in ['day', 'week', 'month', 'year'])
                  ChoiceChip(
                    label: Text(_periodLabel(p), style: const TextStyle(fontSize: 15)),
                    selected: _period == p,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(color: _period == p ? Colors.white : Colors.black87),
                    onSelected: (_) => setState(() => _period = p),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            Text('Generate Report / ವರದಿ ತಯಾರಿಸಿ',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            _ReportButton(
              icon: Icons.picture_as_pdf,
              label: 'Export PDF / PDF ರಫ್ತು',
              color: Colors.red,
              onTap: () => _generateAndShare(context, share: false),
            ),
            const SizedBox(height: 12),
            _ReportButton(
              icon: Icons.share,
              label: 'Share Report / ವರದಿ ಹಂಚಿಕೊಳ್ಳಿ',
              color: Colors.green,
              onTap: () => _generateAndShare(context, share: true),
            ),
            const SizedBox(height: 12),
            _ReportButton(
              icon: Icons.print,
              label: 'Print Report / ಮುದ್ರಿಸಿ',
              color: Colors.blueGrey,
              onTap: () => _printReport(context),
            ),

            const Spacer(),

            if (_generating)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Generating report...\nವರದಿ ತಯಾರಿಸಲಾಗುತ್ತಿದೆ...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<pw.Document> _buildPdf() async {
    final db = AppDatabase();
    final now = DateTime.now();
    DateTime from;
    DateTime to = DateTime(now.year, now.month, now.day + 1);

    switch (_period) {
      case 'day':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        from = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(from.year, from.month, from.day);
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year + 1, 1, 1);
        break;
      default:
        from = DateTime(now.year, now.month, 1);
    }

    final rentals = await db.getRentalsByDateRange(from, to);
    final expenses = await db.getExpensesByDateRange(from, to);
    final allRentals = await db.getAllRentals();

    final activeRentals = rentals.where((r) => r.deletedAt == null).toList();
    final activeExpenses = expenses.where((e) => e.deletedAt == null).toList();

    final totalCollected = activeRentals.fold(0.0, (s, r) => s + r.amountPaid);
    final totalRent = activeRentals.fold(0.0, (s, r) => s + r.rentAmount);
    final totalExpenses = activeExpenses.fold(0.0, (s, e) => s + e.amount);
    final netProfit = totalCollected - totalExpenses;
    final totalPending = allRentals
        .where((r) => r.deletedAt == null && r.status != 'fully_paid')
        .fold(0.0, (s, r) => s + (r.rentAmount - r.amountPaid).clamp(0.0, double.infinity));

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TractorMate Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text(formatDate(now), style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Period: ${_periodLabel(_period)}  |  ${formatDate(from)} to ${formatDate(to)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
        pw.SizedBox(height: 20),

        pw.Header(level: 1, text: 'Summary'),
        pw_table.TableHelper.fromTextArray(
          headers: ['Metric', 'Amount'],
          data: [
            ['Total Rent Charged', formatRupees(totalRent)],
            ['Total Collected', formatRupees(totalCollected)],
            ['Total Expenses', formatRupees(totalExpenses)],
            ['Net Profit', formatRupees(netProfit)],
            ['Overall Pending Balance', formatRupees(totalPending)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green100),
          cellHeight: 30,
        ),
        pw.SizedBox(height: 20),

        if (activeRentals.isNotEmpty) ...[
          pw.Header(level: 1, text: 'Rentals (${activeRentals.length})'),
          pw_table.TableHelper.fromTextArray(
            headers: ['Date', 'Work Type', 'Rent', 'Paid', 'Balance', 'Status'],
            data: activeRentals.map((r) => [
              formatDate(r.date),
              r.workType,
              formatRupees(r.rentAmount),
              formatRupees(r.amountPaid),
              formatRupees((r.rentAmount - r.amountPaid).clamp(0, double.infinity)),
              r.status.replaceAll('_', ' '),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
            cellHeight: 24,
          ),
          pw.SizedBox(height: 20),
        ],

        if (activeExpenses.isNotEmpty) ...[
          pw.Header(level: 1, text: 'Expenses (${activeExpenses.length})'),
          pw_table.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Amount', 'Description'],
            data: activeExpenses.map((e) => [
              formatDate(e.date),
              e.category,
              formatRupees(e.amount),
              e.description ?? '',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.orange50),
            cellHeight: 24,
          ),
        ],
      ],
    ));

    return pdf;
  }

  Future<void> _generateAndShare(BuildContext context, {required bool share}) async {
    setState(() => _generating = true);
    try {
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tractormate_report_${_period}.pdf');
      await file.writeAsBytes(bytes);

      if (share && mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: 'TractorMate Report - $_period',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _printReport(BuildContext context) async {
    setState(() => _generating = true);
    try {
      final pdf = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  String _periodLabel(String p) {
    const m = {'day': 'Today / ಇಂದು', 'week': 'Week / ವಾರ', 'month': 'Month / ತಿಂಗಳು', 'year': 'Year / ವರ್ಷ'};
    return m[p] ?? p;
  }
}

class _ReportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReportButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
