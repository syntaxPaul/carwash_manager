class Booking {
  final String id;
  final String code; // globally unique; includes carwash code
  final String carwashId;
  final int tsCreated;
  final int apptTs;
  final String customerName;
  final String phone;
  final String? vehicle;
  final String? licensePlate;
  final String? service;
  final double? price;
  final String status; // pending/confirmed/in_progress/completed/cancelled
  final String? notes;
  final String source; // app or walk_in
  final String syncStatus; // synced / pending_sync / cancel_pending
  final String? employeeId;
  final String? employeeName;

  Booking({
    required this.id,
    required this.code,
    required this.carwashId,
    required this.tsCreated,
    required this.apptTs,
    required this.customerName,
    required this.phone,
    this.vehicle,
    this.licensePlate,
    this.service,
    this.price,
    required this.status,
    this.notes,
    required this.source,
    this.syncStatus = 'synced',
    this.employeeId,
    this.employeeName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'carwash_id': carwashId,
        'ts_created': tsCreated,
        'appt_ts': apptTs,
        'customer_name': customerName,
        'phone': phone,
        'vehicle': vehicle,
        'license_plate': licensePlate,
        'service': service,
        'price': price,
        'status': status,
        'notes': notes,
        'source': source,
        'sync_status': syncStatus,
        'employee_id': employeeId,
        'employee_name': employeeName,
      };
}
