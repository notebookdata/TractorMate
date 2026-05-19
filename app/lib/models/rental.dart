class Rental {
  final String id;
  final String customerId;
  final String customerName;
  final DateTime date;
  final String workType;
  final double rentAmount;
  final double amountPaid;
  final double balance;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const Rental({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.workType,
    required this.rentAmount,
    required this.amountPaid,
    required this.balance,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory Rental.fromJson(Map<String, dynamic> j) => Rental(
        id: j['id'],
        customerId: j['customer_id'],
        customerName: j['customer_name'] ?? '',
        date: DateTime.parse(j['date']),
        workType: j['work_type'],
        rentAmount: (j['rent_amount'] ?? 0).toDouble(),
        amountPaid: (j['amount_paid'] ?? 0).toDouble(),
        balance: (j['balance'] ?? 0).toDouble(),
        status: j['status'] ?? 'unpaid',
        notes: j['notes'],
        createdAt: DateTime.parse(j['created_at']),
        updatedAt: DateTime.parse(j['updated_at']),
        isSynced: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'date': date.toIso8601String(),
        'work_type': workType,
        'rent_amount': rentAmount,
        'amount_paid': amountPaid,
        'status': status,
        'notes': notes,
        'updated_at': updatedAt.toIso8601String(),
      };

  static String computeStatus(double rentAmount, double amountPaid) {
    if (amountPaid <= 0) return 'unpaid';
    if (amountPaid >= rentAmount) return 'fully_paid';
    return 'partially_paid';
  }
}

const workTypes = [
  'double_plough',
  'rentye',
  'rotavator',
  'trolley_work',
  'cultivators',
  'maize_thresher',
  'soybean_thresher',
];

const workTypeLabels = {
  'double_plough':    'Double Plough / ಡಬಲ್ ನೇಗಿಲು',
  'rentye':           'Rentye / ರೆಂಟ್ಯೆ',
  'rotavator':        'Rotavator / ರೊಟಾವೇಟರ್',
  'trolley_work':     'Trolley Work / ಟ್ರಾಲಿ ಕೆಲಸ',
  'cultivators':      'Cultivators / ಕಲ್ಟಿವೇಟರ್',
  'maize_thresher':   'Maize Thresher / ಮೆಕ್ಕೆಜೋಳ ಮೆಷೀನ್',
  'soybean_thresher': 'Soybean Thresher / ಸೋಯಾಬೀನ್ ಮೆಷೀನ್',
  // legacy values kept for display of old records
  'ploughing':  'Ploughing / ಉಳುಮೆ',
  'sowing':     'Sowing / ಬಿತ್ತನೆ',
  'harvesting': 'Harvesting / ಕೊಯ್ಲು',
  'levelling':  'Levelling / ಸಮತಟ್ಟು',
  'other':      'Other / ಇತರೆ',
};
