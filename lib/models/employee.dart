class Employee {
  final String id;
  final String name;
  final String? phone;

  Employee({required this.id, required this.name, this.phone});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory Employee.fromMap(Map<String, dynamic> m) => Employee(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
      );
}
