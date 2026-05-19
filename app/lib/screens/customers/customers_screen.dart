import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import 'customer_detail_screen.dart';

final _customersProvider = StreamProvider.family<List<CustomersTableData>, String>(
  (ref, search) => AppDatabase().watchAllCustomers(search: search.isEmpty ? null : search),
);

// Reactive balance per customer — re-emits whenever any rental for this customer changes
final _customerBalanceProvider =
    StreamProvider.family<Map<String, double>, String>((ref, customerId) {
  return AppDatabase().watchAllRentals(customerId: customerId).map((rentals) {
    final totalRent = rentals.fold(0.0, (s, r) => s + r.rentAmount);
    final totalPaid = rentals.fold(0.0, (s, r) => s + r.amountPaid);
    return {
      'totalRent': totalRent,
      'totalPaid': totalPaid,
      'balance': totalRent - totalPaid,
    };
  });
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(_customersProvider(_search));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers / ಗ್ರಾಹಕರು'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search / ಹುಡುಕಿ...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomer(context),
        icon: const Icon(Icons.person_add, size: 28),
        label: const Text('Add / ಸೇರಿಸಿ', style: TextStyle(fontSize: 16)),
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (customers) => customers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      _search.isEmpty ? 'No customers yet\nಇನ್ನೂ ಗ್ರಾಹಕರಿಲ್ಲ' : 'No results found',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: customers.length,
                itemBuilder: (ctx, i) => _CustomerTile(customer: customers[i], onRefresh: () {}),
              ),
      ),
    );
  }

  void _showAddCustomer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerForm(
        onSave: (name, phone, notes) async {
          final db = AppDatabase();
          await db.upsertCustomer(CustomersTableCompanion.insert(
            id: const Uuid().v4(),
            name: name,
            phone: drift.Value(phone.isEmpty ? null : phone),
            notes: drift.Value(notes.isEmpty ? null : notes),
            isSynced: const drift.Value(false),
          ));
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

class _CustomerTile extends ConsumerWidget {
  final CustomersTableData customer;
  final VoidCallback onRefresh;

  const _CustomerTile({required this.customer, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch balance stream — updates automatically when any rental changes
    final balanceAsync = ref.watch(_customerBalanceProvider(customer.id));
    final balance = balanceAsync.valueOrNull?['balance'] ?? 0.0;
    final hasRentals = (balanceAsync.valueOrNull?['totalRent'] ?? 0.0) > 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text(
            customer.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        title: Text(customer.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        subtitle: customer.phone != null
            ? Text(customer.phone!, style: const TextStyle(fontSize: 14))
            : null,
        trailing: balanceAsync.isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (balance > 0.01) ...[
                    Text(
                      'Balance: ${formatRupees(balance)}',
                      style: const TextStyle(
                          color: AppTheme.unpaid,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ] else if (hasRentals) ...[
                    const Icon(Icons.check_circle, color: AppTheme.paid, size: 20),
                    const Text('Paid',
                        style: TextStyle(color: AppTheme.paid, fontSize: 12)),
                  ] else ...[
                    Icon(Icons.person_outline,
                        size: 20, color: Colors.grey.shade400),
                    Text('No rentals',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ],
              ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(
                customerId: customer.id, customerName: customer.name),
          ),
        ),
      ),
    );
  }
}

class _CustomerForm extends StatefulWidget {
  final Function(String name, String phone, String notes) onSave;
  final String? initialName;
  final String? initialPhone;
  final String? initialNotes;

  const _CustomerForm({
    required this.onSave,
    this.initialName,
    this.initialPhone,
    this.initialNotes,
  });

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone);
  late final _notesCtrl = TextEditingController(text: widget.initialNotes);

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
        left: 24, right: 24, top: 24,
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
                Text(
                  widget.initialName == null ? 'Add Customer\nಗ್ರಾಹಕ ಸೇರಿಸಿ' : 'Edit Customer',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Name / ಗ್ರಾಹಕರ ಹೆಸರು', prefixIcon: Icon(Icons.person)),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone (optional) / ಫೋನ್', prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional) / ಟಿಪ್ಪಣಿ', prefixIcon: Icon(Icons.notes)),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave(_nameCtrl.text.trim(), _phoneCtrl.text.trim(), _notesCtrl.text.trim());
                }
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

// Export the form for reuse
typedef CustomerFormWidget = _CustomerForm;
