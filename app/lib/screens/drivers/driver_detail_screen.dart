import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../services/auth_service.dart';

final _driverProvider = StreamProvider.family<DriversTableData?, String>(
  (ref, driverId) => AppDatabase().watchDriver(driverId),
);

final _attendancesProvider = StreamProvider.family<List<DriverAttendancesTableData>, String>(
  (ref, driverId) => AppDatabase().watchDriverAttendances(driverId),
);

class DriverDetailScreen extends ConsumerStatefulWidget {
  final String driverId;
  const DriverDetailScreen({required this.driverId, super.key});

  @override
  ConsumerState<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends ConsumerState<DriverDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver Details')),
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
            ],
          ),
        ),
      );
    }

    final driverAsync = ref.watch(_driverProvider(widget.driverId));
    final attendancesAsync = ref.watch(_attendancesProvider(widget.driverId));

    return driverAsync.when(
      data: (driver) {
        if (driver == null || driver.deletedAt != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Driver Not Found')),
            body: const Center(child: Text('Driver not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(driver.name),
            elevation: 0,
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: AppTheme.primary.withOpacity(0.05),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (driver.phone != null && driver.phone!.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(driver.phone!, style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text('Daily Salary: ${formatRupees(driver.dailySalary)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
                    if (driver.notes != null && driver.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(driver.notes!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Attendance / ಹಾಜರಾತಿ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAddAttendance(context, driver),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: attendancesAsync.when(
                  data: (attendances) {
                    final active = attendances.where((a) => a.deletedAt == null).toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    if (active.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No attendance records',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }

                    final totalBalance = active.fold<double>(
                      0,
                      (sum, a) => sum + (a.salaryAmount - a.amountPaid),
                    );

                    return Column(
                      children: [
                        if (totalBalance > 0.01)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Balance:',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                Text(formatRupees(totalBalance),
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.unpaid)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: active.length,
                            itemBuilder: (ctx, i) => _AttendanceTile(attendance: active[i]),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddAttendance(BuildContext context, DriversTableData driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceForm(
        driver: driver,
        onSave: (date, salaryAmount, amountPaid, paymentDate, notes) async {
          final db = AppDatabase();
          await db.upsertDriverAttendance(DriverAttendancesTableCompanion.insert(
            id: const Uuid().v4(),
            driverId: driver.id,
            date: date,
            salaryAmount: salaryAmount,
            amountPaid: Value(amountPaid),
            paymentDate: Value(paymentDate),
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

class _AttendanceTile extends ConsumerWidget {
  final DriverAttendancesTableData attendance;
  const _AttendanceTile({required this.attendance});

  Future<void> _editAttendance(BuildContext context, WidgetRef ref) async {
    // Load driver info for the form
    final driver = await AppDatabase().getDriver(attendance.driverId);
    if (driver == null) return;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceForm(
        driver: driver,
        initial: attendance,
        onSave: (date, salaryAmount, amountPaid, paymentDate, notes) async {
          final db = AppDatabase();
          await db.upsertDriverAttendance(DriverAttendancesTableCompanion(
            id: Value(attendance.id),
            driverId: Value(attendance.driverId),
            date: Value(date),
            salaryAmount: Value(salaryAmount),
            amountPaid: Value(amountPaid),
            paymentDate: Value(paymentDate),
            notes: Value(notes.isEmpty ? null : notes),
            updatedAt: Value(DateTime.now()),
          ));

          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance updated / ಹಾಜರಾತಿಯನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ')),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteAttendance(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attendance / ಹಾಜರಾತಿ ಅಳಿಸಿ'),
        content: const Text(
          'Are you sure you want to delete this attendance record?\n\nನೀವು ಈ ಹಾಜರಾತಿ ದಾಖಲೆಯನ್ನು ಅಳಿಸಲು ಖಚಿತವಾಗಿದ್ದೀರಾ?',
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
        await (db.update(db.driverAttendancesTable)..where((t) => t.id.equals(attendance.id)))
            .write(DriverAttendancesTableCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance deleted / ಹಾಜರಾತಿಯನ್ನು ಅಳಿಸಲಾಗಿದೆ')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting attendance: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = attendance.salaryAmount - attendance.amountPaid;
    final isPaid = balance < 0.01;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            color: isPaid ? Colors.green : Colors.orange,
            size: 26,
          ),
        ),
        title: Text(
          '${attendance.date.day}/${attendance.date.month}/${attendance.date.year}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Salary: ${formatRupees(attendance.salaryAmount)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(width: 12),
                Text('Paid: ${formatRupees(attendance.amountPaid)}',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
              ],
            ),
            if (!isPaid) ...[
              const SizedBox(height: 2),
              Text('Balance: ${formatRupees(balance)}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.unpaid, fontWeight: FontWeight.w600)),
            ],
            if (attendance.paymentDate != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.event_available, size: 12, color: Colors.green.shade600),
                const SizedBox(width: 3),
                Text(
                  'Paid on ${attendance.paymentDate!.day}/${attendance.paymentDate!.month}/${attendance.paymentDate!.year}',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                ),
              ]),
            ],
            if (attendance.notes != null && attendance.notes!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(attendance.notes!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
              onPressed: () => _editAttendance(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteAttendance(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceForm extends StatefulWidget {
  final DriversTableData driver;
  final Function(DateTime date, double salaryAmount, double amountPaid, DateTime? paymentDate, String notes) onSave;
  final DriverAttendancesTableData? initial;

  const _AttendanceForm({required this.driver, required this.onSave, this.initial});

  @override
  State<_AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<_AttendanceForm> {
  final _formKey = GlobalKey<FormState>();
  final _salaryCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  DateTime? _paymentDate;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _date = widget.initial!.date;
      _salaryCtrl.text = widget.initial!.salaryAmount.toStringAsFixed(0);
      _paidCtrl.text = widget.initial!.amountPaid.toStringAsFixed(0);
      _paymentDate = widget.initial!.paymentDate;
      _notesCtrl.text = widget.initial!.notes ?? '';
    } else {
      _salaryCtrl.text = widget.driver.dailySalary.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _amountPaid => double.tryParse(_paidCtrl.text) ?? 0.0;
  double get _salaryAmount => double.tryParse(_salaryCtrl.text) ?? 0.0;
  double get _balance => _salaryAmount - _amountPaid;

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
                  const Text('Add Attendance / ಹಾಜರಾತಿ ಸೇರಿಸಿ',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Driver: ${widget.driver.name}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setState(() => _date = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Text('${_date.day}/${_date.month}/${_date.year}', style: const TextStyle(fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Salary Amount / ಸಂಬಳ ಮೊತ್ತ (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid / ಪಾವತಿಸಿದ ಮೊತ್ತ (₹)',
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_amountPaid > 0) ...[
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (p != null) setState(() => _paymentDate = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary.withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.primary.withOpacity(0.04),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _paymentDate != null
                                ? 'Paid: ${_paymentDate!.day}/${_paymentDate!.month}/${_paymentDate!.year}'
                                : 'Select Payment Date / ಪಾವತಿ ದಿನಾಂಕ',
                            style: TextStyle(
                              fontSize: 15,
                              color: _paymentDate != null ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_salaryAmount > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Balance / ಬಾಕಿ:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                      Text(
                        formatRupees(_balance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _balance > 0.01 ? AppTheme.unpaid : AppTheme.paid,
                        ),
                      ),
                    ],
                  ),
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
                      _date,
                      _salaryAmount,
                      _amountPaid,
                      _amountPaid > 0 ? (_paymentDate ?? DateTime.now()) : null,
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
