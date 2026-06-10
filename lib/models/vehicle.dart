class Vehicle {
  final String id;
  final String customerId;
  final String? make;
  final String? model;
  final int? year;
  final String? licensePlate;
  final String? color;
  final String? preferredService;
  final String? carwashId;

  Vehicle({
    required this.id,
    required this.customerId,
    this.make,
    this.model,
    this.year,
    this.licensePlate,
    this.color,
    this.preferredService,
    this.carwashId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'make': make,
        'model': model,
        'year': year,
        'license_plate': licensePlate,
        'color': color,
        'preferred_service': preferredService,
        'carwash_id': carwashId,
      };
}
