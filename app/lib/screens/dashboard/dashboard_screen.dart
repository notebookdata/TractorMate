import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/sync_badge.dart';
import '../../services/sync_service.dart';

final _dashboardProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = AppDatabase();
  final now = DateTime.now();

  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);
  final yearStart = DateTime(now.year, 1, 1);

  Future<double> earnings(DateTime from, DateTime to) async {
    final rentals = await db.getRentalsByDateRange(from, to);
    return rentals.fold<double>(0.0, (s, r) => s + r.amountPaid);
  }

  Future<double> expenses(DateTime from, DateTime to) async {
    final exps = await db.getExpensesByDateRange(from, to);
    return exps.fold<double>(0.0, (s, e) => s + e.amount);
  }

  final allRentals = await db.getAllRentals();
  final totalPending = allRentals
      .where((r) => r.status != 'fully_paid' && r.deletedAt == null)
      .fold<double>(0.0, (s, r) => s + (r.rentAmount - r.amountPaid).clamp(0.0, double.infinity));

  final todayEnd = todayStart.add(const Duration(days: 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final monthEnd = DateTime(now.year, now.month + 1, 1);
  final yearEnd = DateTime(now.year + 1, 1, 1);

  final todayEarn = await earnings(todayStart, todayEnd);
  final weekEarn = await earnings(weekStart, weekEnd);
  final monthEarn = await earnings(monthStart, monthEnd);
  final yearEarn = await earnings(yearStart, yearEnd);
  final monthExp = await expenses(monthStart, monthEnd);

  return {
    'today': todayEarn,
    'week': weekEarn,
    'month': monthEarn,
    'year': yearEarn,
    'pending': totalPending,
    'net_profit': monthEarn - monthExp,
    'month_expenses': monthExp,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dashboardProvider);
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
                await svc.sync();
                ref.invalidate(_dashboardProvider);
              },
              tooltip: 'Sync',
            ),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_dashboardProvider);
            await ref.read(syncServiceProvider).sync();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Earnings / ಗಳಿಕೆ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1.4,
                  children: [
                    StatCard(label: 'Today\nಇಂದು', amount: d['today']!, icon: Icons.today, color: AppTheme.primary),
                    StatCard(label: 'This Week\nಈ ವಾರ', amount: d['week']!, icon: Icons.date_range, color: Colors.teal),
                    StatCard(label: 'This Month\nಈ ತಿಂಗಳು', amount: d['month']!, icon: Icons.calendar_month, color: Colors.indigo),
                    StatCard(label: 'This Year\nಈ ವರ್ಷ', amount: d['year']!, icon: Icons.bar_chart, color: Colors.deepPurple),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Summary / ಸಾರಾಂಶ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      StatCard(
                        label: 'Total Pending Balance\nಒಟ್ಟು ಬಾಕಿ',
                        amount: d['pending']!,
                        icon: Icons.pending_actions,
                        color: AppTheme.unpaid,
                      ),
                      const SizedBox(height: 4),
                      StatCard(
                        label: 'This Month Expenses\nಈ ತಿಂಗಳ ಖರ್ಚು',
                        amount: d['month_expenses']!,
                        icon: Icons.money_off,
                        color: AppTheme.partial,
                      ),
                      const SizedBox(height: 4),
                      StatCard(
                        label: 'This Month Net Profit\nಈ ತಿಂಗಳ ನಿವ್ವಳ ಲಾಭ',
                        amount: d['net_profit']!,
                        icon: Icons.trending_up,
                        color: d['net_profit']! >= 0 ? AppTheme.paid : AppTheme.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
