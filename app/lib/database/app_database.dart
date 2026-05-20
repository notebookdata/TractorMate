import 'package:drift/drift.dart';
import 'connection/native.dart'
    if (dart.library.html) 'connection/web.dart';

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
  TextColumn get driverName => text().nullable()();       // v2
  DateTimeColumn get paymentDate => dateTime().nullable()(); // v3
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

class DriversTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  RealColumn get dailySalary => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class DriverAttendancesTable extends Table {
  TextColumn get id => text()();
  TextColumn get driverId => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get salaryAmount => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  DateTimeColumn get paymentDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
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

@DriftDatabase(tables: [
  CustomersTable,
  RentalsTable,
  ExpensesTable,
  DriversTable,
  DriverAttendancesTable,
  AppSettingsTable
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());

  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(rentalsTable, rentalsTable.driverName);
          }
          if (from < 3) {
            await migrator.addColumn(rentalsTable, rentalsTable.paymentDate);
          }
          if (from < 6) {
            // Create new tables
            await migrator.createTable(driversTable);
            await migrator.createTable(driverAttendancesTable);
          }
        },
      );

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

  Stream<List<CustomersTableData>> watchAllCustomers({String? search}) {
    final q = select(customersTable)
      ..where((t) => t.deletedAt.isNull());
    if (search != null && search.isNotEmpty) {
      q.where((t) => t.name.lower().like('%${search.toLowerCase()}%'));
    }
    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.watch();
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

  Stream<List<RentalsTableData>> watchAllRentals({String? customerId, String? status}) {
    final q = select(rentalsTable)..where((t) => t.deletedAt.isNull());
    if (customerId != null) {
      q.where((t) => t.customerId.equals(customerId));
    }
    if (status != null) {
      q.where((t) => t.status.equals(status));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return q.watch();
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

  Stream<List<ExpensesTableData>> watchAllExpenses({String? category}) {
    final q = select(expensesTable)..where((t) => t.deletedAt.isNull());
    if (category != null) {
      q.where((t) => t.category.equals(category));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return q.watch();
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

  /// Emits a value whenever any rental or expense row changes.
  /// Screens can watch this to know when to recompute aggregates.
  Stream<int> watchChangeCount() {
    final rentals = selectOnly(rentalsTable)
      ..addColumns([rentalsTable.id.count()]);
    final expenses = selectOnly(expensesTable)
      ..addColumns([expensesTable.id.count()]);
    return rentals.watch().asyncExpand((_) => expenses.watch().map((_) => DateTime.now().millisecondsSinceEpoch));
  }

  // ── Driver queries ─────────────────────────────────────────────────────

  Future<List<DriversTableData>> getAllDrivers() =>
      (select(driversTable)..where((t) => t.deletedAt.isNull())..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<DriversTableData?> getDriver(String id) =>
      (select(driversTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<DriversTableData>> watchAllDrivers() =>
      (select(driversTable)..where((t) => t.deletedAt.isNull())..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<DriversTableData?> getDriverById(String id) =>
      (select(driversTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<DriversTableData?> watchDriver(String id) =>
      (select(driversTable)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<void> upsertDriver(DriversTableCompanion d) =>
      into(driversTable).insertOnConflictUpdate(d);

  Future<void> markDriverSynced(String id) =>
      (update(driversTable)..where((t) => t.id.equals(id)))
          .write(const DriversTableCompanion(isSynced: Value(true)));

  Future<List<DriversTableData>> getUnsyncedDrivers() =>
      (select(driversTable)..where((t) => t.isSynced.equals(false))).get();

  // ── Driver Attendance queries ──────────────────────────────────────────

  Future<List<DriverAttendancesTableData>> getDriverAttendances(String driverId) =>
      (select(driverAttendancesTable)
            ..where((t) => t.driverId.equals(driverId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Stream<List<DriverAttendancesTableData>> watchDriverAttendances(String driverId) =>
      (select(driverAttendancesTable)
            ..where((t) => t.driverId.equals(driverId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<void> upsertDriverAttendance(DriverAttendancesTableCompanion da) =>
      into(driverAttendancesTable).insertOnConflictUpdate(da);

  Future<void> markDriverAttendanceSynced(String id) =>
      (update(driverAttendancesTable)..where((t) => t.id.equals(id)))
          .write(const DriverAttendancesTableCompanion(isSynced: Value(true)));

  Future<List<DriverAttendancesTableData>> getUnsyncedDriverAttendances() =>
      (select(driverAttendancesTable)..where((t) => t.isSynced.equals(false))).get();

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

// Resolved at compile-time: native.dart on mobile, web.dart on browser
QueryExecutor _openConnection() => openConnection();
