class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalRent;
  final double totalPaid;
  final double balance;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.totalRent = 0,
    this.totalPaid = 0,
    this.balance = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'],
        name: j['name'],
        phone: j['phone'],
        notes: j['notes'],
        createdAt: DateTime.parse(j['created_at']),
        updatedAt: DateTime.parse(j['updated_at']),
        totalRent: (j['total_rent'] ?? 0).toDouble(),
        totalPaid: (j['total_paid'] ?? 0).toDouble(),
        balance: (j['balance'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Customer copyWith({String? name, String? phone, String? notes}) => Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        totalRent: totalRent,
        totalPaid: totalPaid,
        balance: balance,
      );
}
