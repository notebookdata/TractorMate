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
      await _pull();
      await _setLastSync(DateTime.now());
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

    if (customers.isEmpty && rentals.isEmpty && expenses.isEmpty) return;

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
    });

    // Mark all as synced
    for (final c in customers) await _db.markCustomerSynced(c.id);
    for (final r in rentals) await _db.markRentalSynced(r.id);
    for (final e in expenses) await _db.markExpenseSynced(e.id);
  }

  Future<void> _pull() async {
    final lastSync = await _getLastSync();
    final data = await _api.pullSync(since: lastSync);

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
  }

  Future<bool> hasPendingChanges() async {
    final c = await _db.getUnsyncedCustomers();
    final r = await _db.getUnsyncedRentals();
    final e = await _db.getUnsyncedExpenses();
    return c.isNotEmpty || r.isNotEmpty || e.isNotEmpty;
  }
}
