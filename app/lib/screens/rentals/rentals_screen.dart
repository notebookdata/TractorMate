import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../widgets/status_chip.dart';
import 'add_rental_screen.dart';

class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
  List<RentalsTableData> _rentals = [];
  bool _loading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = AppDatabase();
    var all = await db.getAllRentals();
    all = all.where((r) => r.deletedAt == null).toList();
    if (_statusFilter != null) {
      all = all.where((r) => r.status == _statusFilter).toList();
    }
    setState(() {
      _rentals = all;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentals / ಬಾಡಿಗೆಗಳು'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All / ಎಲ್ಲಾ')),
              const PopupMenuItem(value: 'unpaid', child: Text('Unpaid / ಪಾವತಿ ಆಗಿಲ್ಲ')),
              const PopupMenuItem(value: 'partially_paid', child: Text('Partial / ಭಾಗಶಃ')),
              const PopupMenuItem(value: 'fully_paid', child: Text('Paid / ಪಾವತಿ')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddRentalScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Add / ಸೇರಿಸಿ', style: TextStyle(fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rentals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.agriculture, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No rentals yet\nಇನ್ನೂ ಬಾಡಿಗೆಗಳಿಲ್ಲ',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _rentals.length,
                      itemBuilder: (ctx, i) => _RentalTile(
                        rental: _rentals[i],
                        onUpdated: _load,
                      ),
                    ),
            ),
    );
  }
}

class _RentalTile extends StatelessWidget {
  final RentalsTableData rental;
  final VoidCallback onUpdated;

  const _RentalTile({required this.rental, required this.onUpdated});

  static const _workLabels = {
    'ploughing': 'Ploughing / ಉಳುಮೆ',
    'sowing': 'Sowing / ಬಿತ್ತನೆ',
    'harvesting': 'Harvesting / ಕೊಯ್ಲು',
    'levelling': 'Levelling / ಸಮತಟ್ಟು',
    'other': 'Other / ಇತರೆ',
  };

  @override
  Widget build(BuildContext context) {
    final balance = rental.rentAmount - rental.amountPaid;

    return Card(
      child: FutureBuilder<CustomersTableData?>(
        future: AppDatabase().getCustomer(rental.customerId),
        builder: (ctx, snap) {
          final customerName = snap.data?.name ?? '...';
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppTheme.statusColor(rental.status).withOpacity(0.12),
              child: Icon(Icons.agriculture, color: AppTheme.statusColor(rental.status)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                StatusChip(status: rental.status, small: true),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${_workLabels[rental.workType] ?? rental.workType}  •  ${formatDate(rental.date)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Rent: ${formatRupees(rental.rentAmount)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    Text('Paid: ${formatRupees(rental.amountPaid)}',
                        style: const TextStyle(color: AppTheme.paid, fontSize: 13)),
                    if (balance > 0) ...[
                      const SizedBox(width: 12),
                      Text('Due: ${formatRupees(balance)}',
                          style: const TextStyle(color: AppTheme.unpaid, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddRentalScreen(editRental: rental)),
            ).then((_) => onUpdated()),
          );
        },
      ),
    );
  }
}
