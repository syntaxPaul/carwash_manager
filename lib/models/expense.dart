class Expense {
  final String id;
  final int ts;
  final String category;
  final double amount;
  final String? notes;

  Expense({
    required this.id,
    required this.ts,
    required this.category,
    required this.amount,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ts': ts,
        'category': category,
        'amount': amount,
        'notes': notes,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        ts: m['ts'] as int,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        notes: m['notes'] as String?,
      );
}
