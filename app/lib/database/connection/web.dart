import 'package:drift/drift.dart';
import 'package:drift/web.dart';

DatabaseConnection openConnection() {
  return DatabaseConnection(
    WebDatabase.withStorage(DriftWebStorage.indexedDb('tractormate_db',
        migrateFromLocalStorage: false)),
  );
}
