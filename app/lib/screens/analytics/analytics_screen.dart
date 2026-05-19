import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _period = 'month';
  Map<String, double> _data = {};
  Map<String, double> _expensesByCategory = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      case 'month':
        from = DateTime(now.year, now.month, 1);
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

    final totalCollected = rentals.fold(0.0, (s, r) => s + r.amountPaid);
    final totalRent = rentals.fold(0.0, (s, r) => s + r.rentAmount);
    final totalExpenses = expenses.fold(0.0, (s, e) => s + e.amount);

    final byCategory = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    setState(() {
      _data = {
        'collected': totalCollected,
        'pending': totalRent - totalCollected,
        'expenses': totalExpenses,
        'profit': totalCollected - totalExpenses,
      };
      _expensesByCategory = byCategory;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics / ವಿಶ್ಲೇಷಣೆ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final p in ['day', 'week', 'month', 'year'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_periodLabel(p), style: const TextStyle(fontSize: 15)),
                              selected: _period == p,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(color: _period == p ? Colors.white : Colors.black87),
                              onSelected: (_) {
                                setState(() => _period = p);
                                _load();
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Earnings vs Expenses bar chart
                  Text('Earnings vs Expenses / ಗಳಿಕೆ vs ಖರ್ಚು',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: [
                          _data['collected'] ?? 0,
                          _data['pending'] ?? 0,
                          _data['expenses'] ?? 0,
                          (_data['profit'] ?? 0).clamp(0, double.infinity),
                          1000,
                        ].reduce((a, b) => a > b ? a : b) * 1.3,
                        barGroups: [
                          _bar(0, _data['collected'] ?? 0, AppTheme.paid, 'Collected'),
                          _bar(1, _data['pending'] ?? 0, AppTheme.partial, 'Pending'),
                          _bar(2, _data['expenses'] ?? 0, AppTheme.danger, 'Expenses'),
                          _bar(3, (_data['profit'] ?? 0).clamp(0, double.infinity), AppTheme.primary, 'Profit'),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                const labels = ['Collected', 'Pending', 'Expenses', 'Profit'];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(labels[v.toInt()],
                                      style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (v, _) => Text(
                                '₹${(v / 1000).toStringAsFixed(0)}k',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Expense breakdown pie chart
                  if (_expensesByCategory.isNotEmpty) ...[
                    Text('Expense Breakdown / ಖರ್ಚಿನ ವಿವರ',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: _buildPieSections(),
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _expensesByCategory.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _categoryColor(e.key),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_catShortLabel(e.key)}\n${formatRupees(e.value)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Summary numbers
                  Text('Summary / ಸಾರಾಂಶ', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SummaryRow('Collected / ಸಂಗ್ರಹಿಸಿದ', _data['collected'] ?? 0, AppTheme.paid),
                  _SummaryRow('Pending / ಬಾಕಿ', _data['pending'] ?? 0, AppTheme.partial),
                  _SummaryRow('Expenses / ಖರ್ಚು', _data['expenses'] ?? 0, AppTheme.danger),
                  const Divider(),
                  _SummaryRow('Net Profit / ನಿವ್ವಳ ಲಾಭ', _data['profit'] ?? 0,
                      (_data['profit'] ?? 0) >= 0 ? AppTheme.paid : AppTheme.danger,
                      bold: true),
                ],
              ),
            ),
    );
  }

  BarChartGroupData _bar(int x, double value, Color color, String label) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: value, color: color, width: 28, borderRadius: BorderRadius.circular(6)),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final total = _expensesByCategory.values.fold(0.0, (s, v) => s + v);
    return _expensesByCategory.entries.map((e) {
      final pct = total > 0 ? (e.value / total * 100) : 0.0;
      return PieChartSectionData(
        value: e.value,
        color: _categoryColor(e.key),
        title: '${pct.toStringAsFixed(0)}%',
        radius: 55,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _categoryColor(String cat) {
    const colors = {
      'diesel': Colors.orange,
      'repairs': Colors.red,
      'maintenance': Colors.blue,
      'spare_parts': Colors.purple,
      'insurance': Colors.teal,
      'other': Colors.grey,
    };
    return colors[cat] ?? Colors.grey;
  }

  String _catShortLabel(String cat) {
    const m = {
      'diesel': 'Diesel',
      'repairs': 'Repairs',
      'maintenance': 'Maint.',
      'spare_parts': 'Spare',
      'insurance': 'Insurance',
      'other': 'Other',
    };
    return m[cat] ?? cat;
  }

  String _periodLabel(String p) {
    const m = {'day': 'Today\nಇಂದು', 'week': 'Week\nವಾರ', 'month': 'Month\nತಿಂಗಳು', 'year': 'Year\nವರ್ಷ'};
    return m[p] ?? p;
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool bold;

  const _SummaryRow(this.label, this.amount, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 17 : 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(formatRupees(amount),
              style: TextStyle(
                fontSize: bold ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }
}
