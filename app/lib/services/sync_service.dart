import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'api_service.dart';

const _keyLastSync = 'last_sync_time';
enum SyncStatus { synced, pending, error, syncing }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

/// Last sync error message — readable by UI for display.
final syncErrorProvider = StateProvider<String?>((ref) => null);

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(apiServiceProvider), ref);
});

class SyncService {
  final ApiService _api;
  final Ref _ref;
  late AppDatabase _db;

  SyncService(this._api, this._ref) {
    _db = AppDatabase();
  }

  Future<DateTime?> _getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_keyLastSync);
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  Future<void> _setLastSync(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, dt.toIso8601String());
  }

  /// Full sync cycle: push local changes → pull server changes.
  Future<bool> sync() async {
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    _ref.read(syncErrorProvider.notifier).state = null;
    try {
      await _push();
      final serverTime = await _pull();
      // Use server time if available, otherwise fall back to local time
      await _setLastSync(serverTime ?? DateTime.now());
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
      return true;
    } catch (e) {
      final msg = _friendlyError(e.toString());
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      _ref.read(syncErrorProvider.notifier).state = msg;
      return false;
    }
  }

  static String _friendlyError(String raw) {
    if (raw.contains('SocketException') || raw.contains('Network is unreachable') || raw.contains('Connection refused')) {
      return 'No internet / server unreachable. Data saved locally.';
    }
    if (raw.contains('401') || raw.contains('Unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (raw.contains('404')) {
      return 'Server API not found. Check server URL in Settings.';
    }
    if (raw.contains('500') || raw.contains('422')) {
      return 'Server error. Please deploy latest backend and run migrate_db.py.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return 'Connection timed out. Check your internet.';
    }
    return 'Sync failed: $raw';
  }

  Future<void> _push() async {
    final customers = await _db.getUnsyncedCustomers();
    final rentals = await _db.getUnsyncedRentals();
    final expenses = await _db.getUnsyncedExpenses();
    final drivers = await _db.getUnsyncedDrivers();
    final driverAttendances = await _db.getUnsyncedDriverAttendances();

    if (customers.isEmpty && rentals.isEmpty && expenses.isEmpty && 
        drivers.isEmpty && driverAttendances.isEmpty) return;

    await _api.pushSync({
      'customers': customers
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'phone': c.phone,
                'notes': c.notes,
                'updated_at': c.updatedAt.toIso8601String(),
                'deleted_at': c.deletedAt?.toIso8601String(),
              })
          .toList(),
      'rentals': rentals
          .map((r) => {
                'id': r.id,
                'customer_id': r.customerId,
                'date': r.date.toIso8601String(),
                'work_type': r.workType,
                'rent_amount': r.rentAmount,
                'amount_paid': r.amountPaid,
                'status': r.status,
                'notes': r.notes,
                'driver_name': r.driverName,
                'payment_date': r.paymentDate?.toIso8601String(),
                'updated_at': r.updatedAt.toIso8601String(),
                'deleted_at': r.deletedAt?.toIso8601String(),
              })
          .toList(),
      'expenses': expenses
          .map((e) => {
                'id': e.id,
                'date': e.date.toIso8601String(),
                'category': e.category,
                'amount': e.amount,
                'description': e.description,
                'updated_at': e.updatedAt.toIso8601String(),
                'deleted_at': e.deletedAt?.toIso8601String(),
              })
          .toList(),
      'drivers': drivers
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'phone': d.phone,
                'daily_salary': d.dailySalary,
                'notes': d.notes,
                'updated_at': d.updatedAt.toIso8601String(),
                'deleted_at': d.deletedAt?.toIso8601String(),
              })
          .toList(),
      'driver_attendances': driverAttendances
          .map((da) => {
                'id': da.id,
                'driver_id': da.driverId,
                'date': da.date.toIso8601String(),
                'salary_amount': da.salaryAmount,
                'amount_paid': da.amountPaid,
                'payment_date': da.paymentDate?.toIso8601String(),
                'notes': da.notes,
                'updated_at': da.updatedAt.toIso8601String(),
                'deleted_at': da.deletedAt?.toIso8601String(),
              })
          .toList(),
    });

    // Mark all as synced
    for (final c in customers) await _db.markCustomerSynced(c.id);
    for (final r in rentals) await _db.markRentalSynced(r.id);
    for (final e in expenses) await _db.markExpenseSynced(e.id);
    for (final d in drivers) await _db.markDriverSynced(d.id);
    for (final da in driverAttendances) await _db.markDriverAttendanceSynced(da.id);
  }

  Future<DateTime?> _pull() async {
    final lastSync = await _getLastSync();
    final data = await _api.pullSync(since: lastSync);

    // Extract server_time from response
    final serverTime = data['server_time'] != null
        ? DateTime.tryParse(data['server_time'])
        : null;

    for (final c in (data['customers'] as List)) {
      await _db.upsertCustomer(CustomersTableCompanion(
        id: Value(c['id']),
        name: Value(c['name']),
        phone: Value(c['phone']),
        notes: Value(c['notes']),
        updatedAt: Value(DateTime.parse(c['updated_at'])),
        deletedAt: Value(c['deleted_at'] != null ? DateTime.parse(c['deleted_at']) : null),
        isSynced: const Value(true),
      ));
    }

    for (final r in (data['rentals'] as List)) {
      await _db.upsertRental(RentalsTableCompanion(
        id: Value(r['id']),
        customerId: Value(r['customer_id']),
        date: Value(DateTime.parse(r['date'])),
        workType: Value(r['work_type']),
        rentAmount: Value((r['rent_amount'] as num).toDouble()),
        amountPaid: Value((r['amount_paid'] as num).toDouble()),
        status: Value(r['status']),
        notes: Value(r['notes']),
        driverName: Value(r['driver_name']),
        paymentDate: Value(r['payment_date'] != null
            ? DateTime.tryParse(r['payment_date'])
            : null),
        updatedAt: Value(DateTime.parse(r['updated_at'])),
        deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at']) : null),
        isSynced: const Value(true),
      ));
    }

    for (final e in (data['expenses'] as List)) {
      await _db.upsertExpense(ExpensesTableCompanion(
        id: Value(e['id']),
        date: Value(DateTime.parse(e['date'])),
        category: Value(e['category']),
        amount: Value((e['amount'] as num).toDouble()),
        description: Value(e['description']),
        updatedAt: Value(DateTime.parse(e['updated_at'])),
        deletedAt: Value(e['deleted_at'] != null ? DateTime.parse(e['deleted_at']) : null),
        isSynced: const Value(true),
      ));
    }

    for (final d in (data['drivers'] as List)) {
      await _db.upsertDriver(DriversTableCompanion(
        id: Value(d['id']),
        name: Value(d['name']),
        phone: Value(d['phone']),
        dailySalary: Value((d['daily_salary'] as num).toDouble()),
        notes: Value(d['notes']),
        updatedAt: Value(DateTime.parse(d['updated_at'])),
        deletedAt: Value(d['deleted_at'] != null ? DateTime.parse(d['deleted_at']) : null),
        isSynced: const Value(true),
      ));
    }

    for (final da in (data['driver_attendances'] as List)) {
      await _db.upsertDriverAttendance(DriverAttendancesTableCompanion(
        id: Value(da['id']),
        driverId: Value(da['driver_id']),
        date: Value(DateTime.parse(da['date'])),
        salaryAmount: Value((da['salary_amount'] as num).toDouble()),
        amountPaid: Value((da['amount_paid'] as num).toDouble()),
        paymentDate: Value(da['payment_date'] != null
            ? DateTime.tryParse(da['payment_date'])
            : null),
        notes: Value(da['notes']),
        updatedAt: Value(DateTime.parse(da['updated_at'])),
        deletedAt: Value(da['deleted_at'] != null ? DateTime.parse(da['deleted_at']) : null),
        isSynced: const Value(true),
      ));
    }

    return serverTime;
  }

  Future<bool> hasPendingChanges() async {
    final c = await _db.getUnsyncedCustomers();
    final r = await _db.getUnsyncedRentals();
    final e = await _db.getUnsyncedExpenses();
    final d = await _db.getUnsyncedDrivers();
    final da = await _db.getUnsyncedDriverAttendances();
    return c.isNotEmpty || r.isNotEmpty || e.isNotEmpty || d.isNotEmpty || da.isNotEmpty;
  }
}
