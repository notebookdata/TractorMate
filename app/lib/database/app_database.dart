import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── Table definitions ─────────────────────────────────────────────────────

class CustomersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class RentalsTable extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(CustomersTable, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get workType => text()();
  RealColumn get rentAmount => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpensesTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── Database class ────────────────────────────────────────────────────────

@DriftDatabase(tables: [CustomersTable, RentalsTable, ExpensesTable, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());

  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  @override
  int get schemaVersion => 1;

  // ── Customer queries ───────────────────────────────────────────────────

  Future<List<CustomersTableData>> getAllCustomers({String? search}) {
    final q = select(customersTable)
      ..where((t) => t.deletedAt.isNull());
    if (search != null && search.isNotEmpty) {
      q.where((t) => t.name.lower().like('%${search.toLowerCase()}%'));
    }
    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.get();
  }

  Future<CustomersTableData?> getCustomer(String id) =>
      (select(customersTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertCustomer(CustomersTableCompanion c) =>
      into(customersTable).insertOnConflictUpdate(c);

  Future<void> markCustomerSynced(String id) =>
      (update(customersTable)..where((t) => t.id.equals(id)))
          .write(const CustomersTableCompanion(isSynced: Value(true)));

  Future<List<CustomersTableData>> getUnsyncedCustomers() =>
      (select(customersTable)..where((t) => t.isSynced.equals(false))).get();

  // ── Rental queries ─────────────────────────────────────────────────────

  Future<List<RentalsTableData>> getAllRentals({String? customerId}) {
    final q = select(rentalsTable)..where((t) => t.deletedAt.isNull());
    if (customerId != null) {
      q.where((t) => t.customerId.equals(customerId));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return q.get();
  }

  Future<void> upsertRental(RentalsTableCompanion r) =>
      into(rentalsTable).insertOnConflictUpdate(r);

  Future<void> markRentalSynced(String id) =>
      (update(rentalsTable)..where((t) => t.id.equals(id)))
          .write(const RentalsTableCompanion(isSynced: Value(true)));

  Future<List<RentalsTableData>> getUnsyncedRentals() =>
      (select(rentalsTable)..where((t) => t.isSynced.equals(false))).get();

  Future<List<RentalsTableData>> getRentalsByDateRange(DateTime from, DateTime to) =>
      (select(rentalsTable)
            ..where((t) => t.deletedAt.isNull())
            ..where((t) => t.date.isBiggerOrEqualValue(from))
            ..where((t) => t.date.isSmallerOrEqualValue(to)))
          .get();

  // ── Expense queries ────────────────────────────────────────────────────

  Future<List<ExpensesTableData>> getAllExpenses({String? category}) {
    final q = select(expensesTable)..where((t) => t.deletedAt.isNull());
    if (category != null) {
      q.where((t) => t.category.equals(category));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return q.get();
  }

  Future<void> upsertExpense(ExpensesTableCompanion e) =>
      into(expensesTable).insertOnConflictUpdate(e);

  Future<void> markExpenseSynced(String id) =>
      (update(expensesTable)..where((t) => t.id.equals(id)))
          .write(const ExpensesTableCompanion(isSynced: Value(true)));

  Future<List<ExpensesTableData>> getUnsyncedExpenses() =>
      (select(expensesTable)..where((t) => t.isSynced.equals(false))).get();

  Future<List<ExpensesTableData>> getExpensesByDateRange(DateTime from, DateTime to) =>
      (select(expensesTable)
            ..where((t) => t.deletedAt.isNull())
            ..where((t) => t.date.isBiggerOrEqualValue(from))
            ..where((t) => t.date.isSmallerOrEqualValue(to)))
          .get();

  // ── Settings ───────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettingsTable)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettingsTable).insertOnConflictUpdate(
        AppSettingsTableCompanion(key: Value(key), value: Value(value)),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tractormate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
