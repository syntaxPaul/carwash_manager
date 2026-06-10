class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final int createdTs;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdTs,
    this.email,
  });

  factory Customer.fromMap(Map<String, Object?> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String?,
        createdTs: map['created_ts'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'created_ts': createdTs,
      };
}
