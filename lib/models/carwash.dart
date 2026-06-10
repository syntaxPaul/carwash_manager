class Carwash {
  final String id;
  final String code; // short code used in booking codes
  final String name;
  final double lat;
  final double lng;
  final String? address;
  final String? phone;
  final String? openHours;
  final List<Map<String, dynamic>> services; // [{name, price}]
  final int? queueLength;
  final int? avgWashMins;

  Carwash({
    required this.id,
    required this.code,
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
    this.phone,
    this.openHours,
    required this.services,
    this.queueLength,
    this.avgWashMins,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'lat': lat,
        'lng': lng,
        'address': address,
        'phone': phone,
        'open_hours': openHours,
        'services_json': services,
        'queue_length': queueLength,
        'avg_wash_mins': avgWashMins,
      };
}
