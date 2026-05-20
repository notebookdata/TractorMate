import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/sync_badge.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';

Future<Map<String, double>> _computeDashboard() async {
  final db = AppDatabase();
  final now = DateTime.now();

  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);
  final yearStart = DateTime(now.year, 1, 1);

  Future<double> earn(DateTime from, DateTime to) async {
    final rows = await db.getRentalsByDateRange(from, to);
    return rows.fold<double>(0.0, (s, r) => s + r.amountPaid);
  }

  Future<double> exp(DateTime from, DateTime to) async {
    final rows = await db.getExpensesByDateRange(from, to);
    return rows.fold<double>(0.0, (s, e) => s + e.amount);
  }

  final allRentals = await db.getAllRentals();
  final totalPending = allRentals
      .where((r) => r.status != 'fully_paid' && r.deletedAt == null)
      .fold<double>(0.0, (s, r) => s + (r.rentAmount - r.amountPaid).clamp(0.0, double.infinity));

  final todayEnd = todayStart.add(const Duration(days: 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final monthEnd = DateTime(now.year, now.month + 1, 1);
  final yearEnd = DateTime(now.year + 1, 1, 1);

  final todayEarn = await earn(todayStart, todayEnd);
  final weekEarn = await earn(weekStart, weekEnd);
  final monthEarn = await earn(monthStart, monthEnd);
  final yearEarn = await earn(yearStart, yearEnd);
  final monthExp = await exp(monthStart, monthEnd);

  return {
    'today': todayEarn,
    'week': weekEarn,
    'month': monthEarn,
    'year': yearEarn,
    'pending': totalPending,
    'net_profit': monthEarn - monthExp,
    'month_expenses': monthExp,
  };
}

// Streams every time any rental row changes → re-computes dashboard figures automatically
final _dashboardProvider = StreamProvider<Map<String, double>>((ref) async* {
  await for (final _ in AppDatabase().watchAllRentals()) {
    yield await _computeDashboard();
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';
    ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TractorMate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('ಟ್ರ್ಯಾಕ್ಟರ್‌ಮೇಟ್', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const SyncBadge(),
              onPressed: () async {
                final svc = ref.read(syncServiceProvider);
                final ok = await svc.sync();
                if (!ok && context.mounted) {
                  final err = ref.read(syncErrorProvider) ?? 'Sync failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(err),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ));
                }
              },
              tooltip: 'Sync / ಸಿಂಕ್',
            ),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Earnings section - Admin only
              if (isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Earnings / ಗಳಿಕೆ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                ),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Today', labelKn: 'ಇಂದು', amount: d['today']!, icon: Icons.today, color: AppTheme.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: StatCard(label: 'This Week', labelKn: 'ಈ ವಾರ', amount: d['week']!, icon: Icons.date_range, color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'This Month', labelKn: 'ಈ ತಿಂಗಳು', amount: d['month']!, icon: Icons.calendar_month, color: Colors.indigo)),
                    const SizedBox(width: 8),
                    Expanded(child: StatCard(label: 'This Year', labelKn: 'ಈ ವರ್ಷ', amount: d['year']!, icon: Icons.bar_chart, color: Colors.deepPurple)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Summary / ಸಾರಾಂಶ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
              ),
              StatCard(
                label: 'Total Pending Balance',
                labelKn: 'ಒಟ್ಟು ಬಾಕಿ',
                amount: d['pending']!,
                icon: Icons.pending_actions,
                color: AppTheme.unpaid,
              ),
              const SizedBox(height: 8),
              StatCard(
                label: 'This Month Expenses',
                labelKn: 'ಈ ತಿಂಗಳ ಖರ್ಚು',
                amount: d['month_expenses']!,
                icon: Icons.money_off,
                color: AppTheme.partial,
              ),
              // Net Profit - Admin only
              if (isAdmin) ...[
                const SizedBox(height: 8),
                StatCard(
                  label: 'This Month Net Profit',
                  labelKn: 'ಈ ತಿಂಗಳ ನಿವ್ವಳ ಲಾಭ',
                  amount: d['net_profit']!,
                  icon: Icons.trending_up,
                  color: d['net_profit']! >= 0 ? AppTheme.paid : AppTheme.danger,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
