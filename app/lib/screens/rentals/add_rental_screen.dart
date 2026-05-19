import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/app_database.dart';
import '../../models/rental.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';

const _prefKeyCustomTypes = 'custom_work_types';

class AddRentalScreen extends ConsumerStatefulWidget {
  final RentalsTableData? editRental;
  final String? preselectedCustomerId;

  const AddRentalScreen({super.key, this.editRental, this.preselectedCustomerId});

  @override
  ConsumerState<AddRentalScreen> createState() => _AddRentalScreenState();
}

class _AddRentalScreenState extends ConsumerState<AddRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rentCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();

  String? _customerId;
  String? _customerName;
  DateTime _date = DateTime.now();
  String _workType = 'double_plough';
  bool _saving = false;

  List<CustomersTableData> _customers = [];
  List<String> _customWorkTypes = [];
  Map<String, String> _customLabels = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadCustomWorkTypes();
    if (widget.editRental != null) {
      final r = widget.editRental!;
      _customerId = r.customerId;
      _date = r.date;
      _workType = r.workType;
      _rentCtrl.text = r.rentAmount.toStringAsFixed(0);
      _paidCtrl.text = r.amountPaid.toStringAsFixed(0);
      _notesCtrl.text = r.notes ?? '';
      _driverCtrl.text = r.driverName ?? '';
    }
    if (widget.preselectedCustomerId != null) {
      _customerId = widget.preselectedCustomerId;
    }
    // Auto-fill driver from logged-in user when adding new rental
    if (widget.editRental == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final username = ref.read(authProvider).username;
        if (username != null && _driverCtrl.text.isEmpty) {
          _driverCtrl.text = username;
        }
      });
    }
  }

  Future<void> _loadCustomers() async {
    final db = AppDatabase();
    final customers = await db.getAllCustomers();
    setState(() {
      _customers = customers;
      if (_customerId != null) {
        _customerName = customers.firstWhere(
          (c) => c.id == _customerId,
          orElse: () => customers.first,
        ).name;
      }
    });
  }

  Future<void> _loadCustomWorkTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKeyCustomTypes) ?? [];
    final labels = <String, String>{};
    for (final key in saved) {
      final label = prefs.getString('wt_label_$key');
      if (label != null) labels[key] = label;
    }
    setState(() {
      _customWorkTypes = saved;
      _customLabels = labels;
    });
  }

  Future<void> _addCustomWorkType() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Work Type\nಕೆಲಸದ ವಿಧ ಸೇರಿಸಿ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Paddy Harvest / ಭತ್ತ ಕೊಯ್ಲು',
            prefixIcon: Icon(Icons.agriculture),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel / ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add / ಸೇರಿಸಿ'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    // Build a URL-safe key from the name
    final key = 'custom_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefKeyCustomTypes) ?? [];

    if (!existing.contains(key)) {
      existing.add(key);
      await prefs.setStringList(_prefKeyCustomTypes, existing);
      // Also persist the display label so it shows correctly everywhere
      await prefs.setString('wt_label_$key', name);
    }

    if (mounted) {
      setState(() {
        if (!_customWorkTypes.contains(key)) _customWorkTypes.add(key);
        _customLabels[key] = name;
        _workType = key;
      });
    }
  }

  /// Resolve display label: built-in map first, then user-saved labels, then raw key.
  String _resolveLabel(String wt) =>
      workTypeLabels[wt] ?? _customLabels[wt] ?? wt;

  /// All work types: built-in + user-added custom ones.
  List<String> get _allWorkTypes => [...workTypes, ..._customWorkTypes];

  @override
  void dispose() {
    _rentCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _driverCtrl.dispose();
    super.dispose();
  }

  double get _rentAmount => double.tryParse(_rentCtrl.text) ?? 0;
  double get _amountPaid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _balance => (_rentAmount - _amountPaid).clamp(0.0, double.infinity);
  String get _status => Rental.computeStatus(_rentAmount, _amountPaid);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer / ಗ್ರಾಹಕರನ್ನು ಆಯ್ಕೆ ಮಾಡಿ')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = AppDatabase();
    final id = widget.editRental?.id ?? const Uuid().v4();
    await db.upsertRental(RentalsTableCompanion(
      id: Value(id),
      customerId: Value(_customerId!),
      date: Value(_date),
      workType: Value(_workType),
      rentAmount: Value(_rentAmount),
      amountPaid: Value(_amountPaid),
      status: Value(_status),
      notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      driverName: Value(_driverCtrl.text.trim().isEmpty ? null : _driverCtrl.text.trim()),
      updatedAt: Value(DateTime.now()),
      isSynced: const Value(false),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editRental == null
            ? 'Add Rental / ಬಾಡಿಗೆ ಸೇರಿಸಿ'
            : 'Edit Rental / ಬದಲಾಯಿಸಿ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer picker
              Text('Customer / ಗ್ರಾಹಕರು', style: _labelStyle),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickCustomer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _customerName ?? 'Select customer / ಆಯ್ಕೆ ಮಾಡಿ',
                          style: TextStyle(
                            fontSize: 16,
                            color: _customerId == null ? Colors.grey.shade500 : Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date picker
              Text('Date / ದಿನಾಂಕ', style: _labelStyle),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Text(formatDate(_date), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Work type dropdown
              Text('Work Type / ಕೆಲಸದ ವಿಧ', style: _labelStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _allWorkTypes.contains(_workType) ? _workType : _allWorkTypes.first,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.agriculture, color: AppTheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                isExpanded: true,
                items: [
                  // Built-in + saved custom types
                  ..._allWorkTypes.map((wt) => DropdownMenuItem(
                        value: wt,
                        child: Text(
                          _resolveLabel(wt),
                          style: const TextStyle(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                  // Special sentinel item to add a new type
                  const DropdownMenuItem(
                    value: '__add_custom__',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Add custom type / ಹೊಸ ವಿಧ ಸೇರಿಸಿ',
                            style: TextStyle(fontSize: 15, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == '__add_custom__') {
                    _addCustomWorkType();
                  } else if (v != null) {
                    setState(() => _workType = v);
                  }
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),

              // Driver / operator name
              Text('Driver / ಚಾಲಕ', style: _labelStyle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverCtrl,
                decoration: InputDecoration(
                  hintText: 'Driver name / ಚಾಲಕರ ಹೆಸರು',
                  prefixIcon: const Icon(Icons.person_pin, color: AppTheme.primary),
                  suffixIcon: ref.watch(authProvider).username != null
                      ? Tooltip(
                          message: 'Use logged-in user',
                          child: IconButton(
                            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primary),
                            onPressed: () => setState(() =>
                                _driverCtrl.text = ref.read(authProvider).username ?? ''),
                          ),
                        )
                      : null,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Rent amount
              TextFormField(
                controller: _rentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rent Amount / ಬಾಡಿಗೆ ಮೊತ್ತ (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount paid
              TextFormField(
                controller: _paidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid / ಪಾವತಿ ಮಾಡಿದ ಮೊತ್ತ (₹)',
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Live status preview
              if (_rentCtrl.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.statusColor(_status).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.statusColor(_status).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status / ಸ್ಥಿತಿ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          Text(_statusLabel(_status),
                              style: TextStyle(
                                color: AppTheme.statusColor(_status),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              )),
                        ],
                      ),
                      if (_balance > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Remaining / ಬಾಕಿ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            Text(formatRupees(_balance),
                                style: const TextStyle(
                                    color: AppTheme.unpaid, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional) / ಟಿಪ್ಪಣಿ',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 24),
                      label: Text(
                        widget.editRental == null ? 'Save Rental / ಉಳಿಸಿ' : 'Update / ಅಪ್ಡೇಟ್',
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final selected = await showModalBottomSheet<CustomersTableData>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(customers: _customers),
    );
    if (selected != null) {
      setState(() {
        _customerId = selected.id;
        _customerName = selected.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  TextStyle get _labelStyle => const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87);

  String _statusLabel(String s) {
    const m = {
      'fully_paid': 'Fully Paid / ಸಂಪೂರ್ಣ ಪಾವತಿ',
      'partially_paid': 'Partially Paid / ಭಾಗಶಃ',
      'unpaid': 'Unpaid / ಪಾವತಿ ಆಗಿಲ್ಲ',
    };
    return m[s] ?? s;
  }
}

class _CustomerPickerSheet extends StatelessWidget {
  final List<CustomersTableData> customers;
  const _CustomerPickerSheet({required this.customers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Select Customer / ಗ್ರಾಹಕರನ್ನು ಆಯ್ಕೆ ಮಾಡಿ',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: customers.length,
              itemBuilder: (ctx, i) {
                final c = customers[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(c.name[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontSize: 17)),
                  subtitle: c.phone != null ? Text(c.phone!) : null,
                  onTap: () => Navigator.pop(ctx, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
