import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/app_database.dart';
import '../../models/expense.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';

final _expensesProvider = StreamProvider.family<List<ExpensesTableData>, String?>(
  (ref, category) => AppDatabase().watchAllExpenses(category: category),
);

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(_expensesProvider(_categoryFilter));
    final expenses = expensesAsync.valueOrNull ?? [];
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses / ಖರ್ಚುಗಳು'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _categoryFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All / ಎಲ್ಲಾ')),
              const PopupMenuItem(value: 'diesel', child: Text('Diesel / ಡೀಸೆಲ್')),
              const PopupMenuItem(value: 'repairs', child: Text('Repairs / ದುರಸ್ತಿ')),
              const PopupMenuItem(value: 'maintenance', child: Text('Maintenance / ನಿರ್ವಹಣೆ')),
              const PopupMenuItem(value: 'spare_parts', child: Text('Spare Parts / ಬಿಡಿ ಭಾಗ')),
              const PopupMenuItem(value: 'insurance', child: Text('Insurance / ವಿಮೆ')),
              const PopupMenuItem(value: 'other', child: Text('Other / ಇತರೆ')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Text(
                  'Total: ${formatRupees(total)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('(${expenses.length} entries)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpense(context),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Add / ಸೇರಿಸಿ', style: TextStyle(fontSize: 16)),
      ),
      body: expensesAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {},
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No expenses yet\nಇನ್ನೂ ಖರ್ಚುಗಳಿಲ್ಲ',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: expenses.length,
                      itemBuilder: (ctx, i) => _ExpenseTile(
                        expense: expenses[i],
                        onUpdated: () {},
                      ),
                    ),
            ),
    );
  }

  void _showAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseForm(
        onSave: (date, category, amount, description) async {
          final db = AppDatabase();
          await db.upsertExpense(ExpensesTableCompanion.insert(
            id: const Uuid().v4(),
            date: date,
            category: category,
            amount: amount,
            description: Value(description.isEmpty ? null : description),
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

class _ExpenseTile extends StatelessWidget {
  final ExpensesTableData expense;
  final VoidCallback onUpdated;

  const _ExpenseTile({required this.expense, required this.onUpdated});

  static const _catIcons = {
    'diesel': Icons.local_gas_station,
    'repairs': Icons.build,
    'maintenance': Icons.settings,
    'spare_parts': Icons.construction,
    'insurance': Icons.security,
    'other': Icons.more_horiz,
  };

  static const _catLabels = {
    'diesel': 'Diesel / ಡೀಸೆಲ್',
    'repairs': 'Repairs / ದುರಸ್ತಿ',
    'maintenance': 'Maintenance / ನಿರ್ವಹಣೆ',
    'spare_parts': 'Spare Parts / ಬಿಡಿ ಭಾಗ',
    'insurance': 'Insurance / ವಿಮೆ',
    'other': 'Other / ಇತರೆ',
  };

  static const _catColors = {
    'diesel': Colors.orange,
    'repairs': Colors.red,
    'maintenance': Colors.blue,
    'spare_parts': Colors.purple,
    'insurance': Colors.teal,
    'other': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final color = _catColors[expense.category] ?? Colors.grey;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (color as Color).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_catIcons[expense.category] ?? Icons.more_horiz, color: color, size: 26),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(_catLabels[expense.category] ?? expense.category,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Text(formatRupees(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.danger)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(formatDate(expense.date),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            if (expense.description != null && expense.description!.isNotEmpty)
              Text(expense.description!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  final Function(DateTime date, String category, double amount, String description) onSave;
  final ExpensesTableData? initial;

  const _ExpenseForm({required this.onSave, this.initial});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String _category = 'diesel';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _date = widget.initial!.date;
      _category = widget.initial!.category;
      _amountCtrl.text = widget.initial!.amount.toStringAsFixed(0);
      _descCtrl.text = widget.initial!.description ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Add Expense / ಖರ್ಚು ಸೇರಿಸಿ',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),

              // Date
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
                    Text(formatDate(_date), style: const TextStyle(fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // Category chips
              const Text('Category / ವರ್ಗ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: expenseCategories.map((cat) {
                  final labels = {
                    'diesel': 'Diesel\nಡೀಸೆಲ್',
                    'repairs': 'Repairs\nದುರಸ್ತಿ',
                    'maintenance': 'Maintenance\nನಿರ್ವಹಣೆ',
                    'spare_parts': 'Spare Parts\nಬಿಡಿ ಭಾಗ',
                    'insurance': 'Insurance\nವಿಮೆ',
                    'other': 'Other\nಇತರೆ',
                  };
                  return ChoiceChip(
                    label: Text(labels[cat] ?? cat, style: const TextStyle(fontSize: 13)),
                    selected: _category == cat,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(color: _category == cat ? Colors.white : Colors.black87),
                    onSelected: (_) => setState(() => _category = cat),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount / ಮೊತ್ತ (₹)',
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
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional) / ವಿವರಣೆ',
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
                      _category,
                      double.parse(_amountCtrl.text),
                      _descCtrl.text.trim(),
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
