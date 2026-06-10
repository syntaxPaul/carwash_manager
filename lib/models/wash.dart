class Wash {
  final String id;
  final int ts; // milliseconds since epoch
  final String? serviceId;
  final String serviceName;
  final double price;
  final String paymentMethod;
  final String? employeeId;
  final String? employeeName;
  final String? notes;
  final String? bookingId;
  final String? vehicle;
  final String? licensePlate;

  Wash({
    required this.id,
    required this.ts,
    this.serviceId,
    required this.serviceName,
    required this.price,
    required this.paymentMethod,
    this.employeeId,
    this.employeeName,
    this.notes,
    this.bookingId,
    this.vehicle,
    this.licensePlate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ts': ts,
        'service_id': serviceId,
        'service_name': serviceName,
        'price': price,
        'payment_method': paymentMethod,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'notes': notes,
        'booking_id': bookingId,
        'vehicle': vehicle,
        'license_plate': licensePlate,
      };

  factory Wash.fromMap(Map<String, dynamic> m) => Wash(
        id: m['id'] as String,
        ts: m['ts'] as int,
        serviceId: m['service_id'] as String?,
        serviceName: m['service_name'] as String,
        price: (m['price'] as num).toDouble(),
        paymentMethod: m['payment_method'] as String,
        employeeId: m['employee_id'] as String?,
        employeeName: m['employee_name'] as String?,
        notes: m['notes'] as String?,
        bookingId: m['booking_id'] as String?,
        vehicle: m['vehicle'] as String?,
        licensePlate: m['license_plate'] as String?,
      );
}
