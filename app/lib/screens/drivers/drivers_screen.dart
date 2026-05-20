import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import 'driver_detail_screen.dart';
import '../../services/auth_service.dart';

final _driversProvider = StreamProvider<List<DriversTableData>>(
  (ref) => AppDatabase().watchAllDrivers(),
);

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Drivers / ಚಾಲಕರು'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Admin Access Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Only administrators can manage drivers',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final driversAsync = ref.watch(_driversProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers / ಚಾಲಕರು'),
        elevation: 0,
      ),
      body: driversAsync.when(
        data: (drivers) {
          final activeDrivers = drivers.where((d) => d.deletedAt == null).toList();
          if (activeDrivers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No drivers / ಯಾವುದೇ ಚಾಲಕರಿಲ್ಲ',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeDrivers.length,
            itemBuilder: (ctx, i) => _DriverTile(driver: activeDrivers[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDriver(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Driver / ಚಾಲಕರನ್ನು ಸೇರಿಸಿ'),
      ),
    );
  }

  void _showAddDriver(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverForm(
        onSave: (name, phone, dailySalary, notes) async {
          final existing = await AppDatabase().getAllDrivers();
          final duplicate = existing.any((d) => 
            d.name.toLowerCase() == name.toLowerCase() && d.deletedAt == null
          );

          if (duplicate && mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Duplicate Name / ನಕಲಿ ಹೆಸರು'),
                content: const Text('A driver with this name already exists.\n\nಈ ಹೆಸರಿನ ಚಾಲಕರು ಈಗಾಗಲೇ ಅಸ್ತಿತ್ವದಲ್ಲಿದ್ದಾರೆ.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }

          final db = AppDatabase();
          await db.upsertDriver(DriversTableCompanion.insert(
            id: const Uuid().v4(),
            name: name,
            phone: Value(phone.isEmpty ? null : phone),
            dailySalary: Value(dailySalary),
            notes: Value(notes.isEmpty ? null : notes),
            isSynced: const Value(false),
          ));
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

class _DriverTile extends ConsumerWidget {
  final DriversTableData driver;
  const _DriverTile({required this.driver});

  Future<void> _editDriver(BuildContext context, WidgetRef ref) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverForm(
        initial: driver,
        onSave: (name, phone, dailySalary, notes) async {
          final existing = await AppDatabase().getAllDrivers();
          final duplicate = existing.any((d) => 
            d.name.toLowerCase() == name.toLowerCase() && 
            d.id != driver.id && 
            d.deletedAt == null
          );

          if (duplicate) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Duplicate Name / ನಕಲಿ ಹೆಸರು'),
                  content: const Text('A driver with this name already exists.\n\nಈ ಹೆಸರಿನ ಚಾಲಕರು ಈಗಾಗಲೇ ಅಸ್ತಿತ್ವದಲ್ಲಿದ್ದಾರೆ.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
            return;
          }

          final db = AppDatabase();
          await db.upsertDriver(DriversTableCompanion(
            id: Value(driver.id),
            name: Value(name),
            phone: Value(phone.isEmpty ? null : phone),
            dailySalary: Value(dailySalary),
            notes: Value(notes.isEmpty ? null : notes),
            updatedAt: Value(DateTime.now()),
          ));

          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Driver updated / ಚಾಲಕರನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ')),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteDriver(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Driver / ಚಾಲಕರನ್ನು ಅಳಿಸಿ'),
        content: Text(
          'Are you sure you want to delete ${driver.name}? This will also delete all attendance records.\n\nನೀವು ${driver.name} ಅನ್ನು ಅಳಿಸಲು ಖಚಿತವಾಗಿದ್ದೀರಾ? ಇದು ಎಲ್ಲಾ ಹಾಜರಾತಿ ದಾಖಲೆಗಳನ್ನು ಸಹ ಅಳಿಸುತ್ತದೆ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel / ರದ್ದುಮಾಡಿ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete / ಅಳಿಸಿ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = AppDatabase();
        // Soft delete by setting deletedAt timestamp and mark as unsynced
        await (db.update(db.driversTable)..where((t) => t.id.equals(driver.id)))
            .write(DriversTableCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver deleted / ಚಾಲಕರನ್ನು ಅಳಿಸಲಾಗಿದೆ')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting driver: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person, color: AppTheme.primary, size: 26),
        ),
        title: Text(driver.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (driver.phone != null && driver.phone!.isNotEmpty)
              Row(children: [
                Icon(Icons.phone, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(driver.phone!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ]),
            const SizedBox(height: 2),
            Text('Daily: ${formatRupees(driver.dailySalary)}',
                style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primary),
              onPressed: () => _editDriver(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteDriver(context, ref),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DriverDetailScreen(driverId: driver.id)),
          );
        },
      ),
    );
  }
}

class _DriverForm extends StatefulWidget {
  final Function(String name, String phone, double dailySalary, String notes) onSave;
  final DriversTableData? initial;

  const _DriverForm({required this.onSave, this.initial});

  @override
  State<_DriverForm> createState() => _DriverFormState();
}

class _DriverFormState extends State<_DriverForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _nameCtrl.text = widget.initial!.name;
      _phoneCtrl.text = widget.initial!.phone ?? '';
      _salaryCtrl.text = widget.initial!.dailySalary.toStringAsFixed(0);
      _notesCtrl.text = widget.initial!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _salaryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Add Driver / ಚಾಲಕರನ್ನು ಸೇರಿಸಿ',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name / ಹೆಸರು',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional) / ದೂರವಾಣಿ',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Daily Salary / ದೈನಂದಿನ ಸಂಬಳ (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional) / ಟಿಪ್ಪಣಿಗಳು',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSave(
                      _nameCtrl.text.trim(),
                      _phoneCtrl.text.trim(),
                      double.parse(_salaryCtrl.text),
                      _notesCtrl.text.trim(),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save / ಉಳಿಸಿ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
