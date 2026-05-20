import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../widgets/status_chip.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../models/rental.dart';
import '../rentals/add_rental_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  List<RentalsTableData> _rentals = [];
  CustomersTableData? _customer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase();
    final customer = await db.getCustomer(widget.customerId);
    final rentals = await db.getAllRentals(customerId: widget.customerId);
    setState(() {
      _customer = customer;
      _rentals = rentals.where((r) => r.deletedAt == null).toList();
      _loading = false;
    });
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer / ಗ್ರಾಹಕರನ್ನು ಅಳಿಸಿ'),
        content: Text(
          'Are you sure you want to delete ${widget.customerName}? This will also delete all associated rentals.\n\nನೀವು ${widget.customerName} ಅನ್ನು ಅಳಿಸಲು ಖಚಿತವಾಗಿದ್ದೀರಾ? ಇದು ಎಲ್ಲಾ ಸಂಬಂಧಿತ ಬಾಡಿಗೆಗಳನ್ನು ಸಹ ಅಳಿಸುತ್ತದೆ.',
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
        await ref.read(apiServiceProvider).deleteCustomer(widget.customerId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final totalRent = _rentals.fold(0.0, (s, r) => s + r.rentAmount);
    final totalPaid = _rentals.fold(0.0, (s, r) => s + r.amountPaid);
    final balance = totalRent - totalPaid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editCustomer,
          ),
          if (kIsWeb && authState.role == 'admin')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteCustomer,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddRentalScreen(preselectedCustomerId: widget.customerId),
          ),
        ).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Add Rental / ಬಾಡಿಗೆ ಸೇರಿಸಿ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Summary card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryItem(label: 'Total Rent\nಒಟ್ಟು ಬಾಡಿಗೆ', value: formatRupees(totalRent)),
                              Container(width: 1, height: 50, color: Colors.white30),
                              _SummaryItem(label: 'Total Paid\nಒಟ್ಟು ಪಾವತಿ', value: formatRupees(totalPaid)),
                              Container(width: 1, height: 50, color: Colors.white30),
                              _SummaryItem(
                                label: 'Balance\nಬಾಕಿ',
                                value: formatRupees(balance),
                                highlight: balance > 0,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_rentals.length} rentals',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    // Phone / notes
                    if (_customer?.phone != null || _customer?.notes != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_customer?.phone != null)
                                  Row(children: [
                                    const Icon(Icons.phone, size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 8),
                                    Text(_customer!.phone!, style: const TextStyle(fontSize: 16)),
                                  ]),
                                if (_customer?.notes != null) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.notes, size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_customer!.notes!, style: const TextStyle(fontSize: 15))),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text('Rental History / ಬಾಡಿಗೆ ಇತಿಹಾಸ',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),

                    if (_rentals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.agriculture, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No rentals yet\nಇನ್ನೂ ಬಾಡಿಗೆಗಳಿಲ್ಲ',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    else
                      ...(_rentals.map((r) => _RentalTile(rental: r, onUpdated: _load))),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  void _editCustomer() {
    if (_customer == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCustomerForm(
        initial: _customer!,
        onSave: (name, phone, notes) async {
          final db = AppDatabase();
          
          // Check for duplicate name (excluding current customer)
          final existing = await db.getAllCustomers();
          if (existing.any((c) => 
              c.id != _customer!.id && 
              c.name.toLowerCase() == name.toLowerCase())) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Duplicate Customer / ನಕಲಿ ಗ್ರಾಹಕ'),
                  content: Text('Customer "$name" already exists!\n\nಗ್ರಾಹಕ "$name" ಈಗಾಗಲೇ ಅಸ್ತಿತ್ವದಲ್ಲಿದೆ!'),
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
          
          await db.upsertCustomer(CustomersTableCompanion(
            id: drift.Value(_customer!.id),
            name: drift.Value(name),
            phone: drift.Value(phone.isEmpty ? null : phone),
            notes: drift.Value(notes.isEmpty ? null : notes),
            updatedAt: drift.Value(DateTime.now()),
            isSynced: const drift.Value(false),
          ));
          if (mounted) {
            Navigator.pop(context);
            _load();
          }
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryItem({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                color: highlight ? const Color(0xFFFFCC80) : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
}

class _RentalTile extends StatelessWidget {
  final RentalsTableData rental;
  final VoidCallback onUpdated;

  const _RentalTile({required this.rental, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final balance = rental.rentAmount - rental.amountPaid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.agriculture, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(_workTypeLabel(rental.workType),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                StatusChip(status: rental.status, small: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(formatDate(rental.date), style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AmountRow(label: 'Rent', amount: rental.rentAmount),
                _AmountRow(label: 'Paid', amount: rental.amountPaid, color: AppTheme.paid),
                if (balance > 0)
                  _AmountRow(label: 'Due', amount: balance, color: AppTheme.unpaid),
              ],
            ),
            if (rental.driverName != null && rental.driverName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person_pin, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(rental.driverName!,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ],
            if (rental.paymentDate != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.event_available, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text('Paid on ${formatDate(rental.paymentDate!)}',
                    style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
            if (rental.notes != null && rental.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(rental.notes!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  String _workTypeLabel(String wt) => workTypeLabels[wt] ?? wt;
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;

  const _AmountRow({required this.label, required this.amount, this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(formatRupees(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color ?? Colors.black87,
              )),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );
}

// ── Edit customer bottom-sheet form ───────────────────────────────────────

class _EditCustomerForm extends StatefulWidget {
  final CustomersTableData initial;
  final Future<void> Function(String name, String phone, String notes) onSave;

  const _EditCustomerForm({required this.initial, required this.onSave});

  @override
  State<_EditCustomerForm> createState() => _EditCustomerFormState();
}

class _EditCustomerFormState extends State<_EditCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initial.name);
  late final _phoneCtrl = TextEditingController(text: widget.initial.phone ?? '');
  late final _notesCtrl = TextEditingController(text: widget.initial.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Edit Customer / ಗ್ರಾಹಕ ಬದಲಿಸಿ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name / ಗ್ರಾಹಕರ ಹೆಸರು',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone (optional) / ಫೋನ್',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional) / ಟಿಪ್ಪಣಿ',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _saving = true);
                      await widget.onSave(
                        _nameCtrl.text.trim(),
                        _phoneCtrl.text.trim(),
                        _notesCtrl.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save / ಉಳಿಸಿ'),
                  ),
          ],
        ),
      ),
    );
  }
}
