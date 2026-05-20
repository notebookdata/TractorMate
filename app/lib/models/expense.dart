class Expense {
  final String id;
  final DateTime date;
  final String category;
  final double amount;
  final String? description;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    this.description,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        date: DateTime.parse(j['date']),
        category: j['category'],
        amount: (j['amount'] ?? 0).toDouble(),
        description: j['description'],
        photoUrl: j['photo_url'],
        createdAt: DateTime.parse(j['created_at']),
        updatedAt: DateTime.parse(j['updated_at']),
        isSynced: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category,
        'amount': amount,
        'description': description,
        'updated_at': updatedAt.toIso8601String(),
      };
}

const expenseCategories = [
  'diesel',
  'repairs',
  'maintenance',
  'spare_parts',
  'insurance',
  'other',
];

const Map<String, String> expenseCategoryLabels = {
  'diesel': 'Diesel / ಡೀಸೆಲ್',
  'repairs': 'Repairs / ದುರಸ್ತಿ',
  'maintenance': 'Maintenance / ನಿರ್ವಹಣೆ',
  'spare_parts': 'Spare Parts / ಬಿಡಿಭಾಗಗಳು',
  'insurance': 'Insurance / ವಿಮೆ',
  'other': 'Other / ಇತರೆ',
};
