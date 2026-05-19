import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../widgets/status_chip.dart';
import 'add_rental_screen.dart';

// Key: status filter (null = all)
final _rentalsProvider = StreamProvider.family<List<RentalsTableData>, String?>(
  (ref, status) => AppDatabase().watchAllRentals(status: status),
);

class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final rentalsAsync = ref.watch(_rentalsProvider(_statusFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentals / ಬಾಡಿಗೆಗಳು'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All / ಎಲ್ಲಾ')),
              PopupMenuItem(value: 'unpaid', child: Text('Unpaid / ಪಾವತಿ ಆಗಿಲ್ಲ')),
              PopupMenuItem(value: 'partially_paid', child: Text('Partial / ಭಾಗಶಃ')),
              PopupMenuItem(value: 'fully_paid', child: Text('Paid / ಪಾವತಿ')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddRentalScreen()),
        ),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Add / ಸೇರಿಸಿ', style: TextStyle(fontSize: 16)),
      ),
      body: rentalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rentals) => rentals.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.agriculture, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No rentals yet\nಇನ್ನೂ ಬಾಡಿಗೆಗಳಿಲ್ಲ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: rentals.length,
                itemBuilder: (ctx, i) => _RentalTile(rental: rentals[i]),
              ),
      ),
    );
  }
}

class _RentalTile extends StatelessWidget {
  final RentalsTableData rental;

  const _RentalTile({required this.rental});

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
              backgroundColor: AppTheme.statusColor(rental.status).withValues(alpha: 0.12),
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
                Wrap(
                  spacing: 12,
                  children: [
                    Text('Rent: ${formatRupees(rental.rentAmount)}',
                        style: const TextStyle(fontSize: 13)),
                    Text('Paid: ${formatRupees(rental.amountPaid)}',
                        style: const TextStyle(color: AppTheme.paid, fontSize: 13)),
                    if (balance > 0)
                      Text('Due: ${formatRupees(balance)}',
                          style: const TextStyle(
                              color: AppTheme.unpaid, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddRentalScreen(editRental: rental)),
            ),
          );
        },
      ),
    );
  }
}
