class Service {
  final String id;
  final String name;
  final double price;

  Service({required this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
      };

  factory Service.fromMap(Map<String, dynamic> m) => Service(
        id: m['id'] as String,
        name: m['name'] as String,
        price: (m['price'] as num).toDouble(),
      );
}
