import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/db.dart';
import '../../utils/format.dart';
import '../../widgets/app_background.dart';
import '../../widgets/customer_nav.dart';

class CustomerMapScreen extends StatefulWidget {
  const CustomerMapScreen({super.key});

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends State<CustomerMapScreen> {
  GoogleMapController? _map;
  LatLng _center = const LatLng(-26.2041, 28.0473); // Johannesburg default
  bool _loading = true;
  final bool _mapAvailable = true;
  final Set<Marker> _markers = {};
  List<Map<String, Object?>> _carwashes = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadCarwashes();
    await _ensureLocation();
    setState(() => _loading = false);
  }

  Future<void> _loadCarwashes() async {
    final db = await AppDb.instance.db;
    final rows = await db.query('carwashes');
    _carwashes = rows;
    _markers.clear();
    for (final c in rows) {
      final lat = (c['lat'] as num).toDouble();
      final lng = (c['lng'] as num).toDouble();
      final name = c['name'] as String;
      final servicesJson = c['services_json'] as String?;
      String subtitle = c['address'] as String? ?? '';
      if (servicesJson != null) {
        final services =
            (json.decode(servicesJson) as List).cast<Map<String, dynamic>>();
        if (services.isNotEmpty) {
          subtitle =
              '${services.first['name']} from ${money((services.first['price'] as num).toDouble())}';
        }
      }
      _markers.add(
        Marker(
          markerId: MarkerId(c['id'] as String),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: subtitle,
            onTap: () => Navigator.pushNamed(
              context,
              '/customer/carwash',
              arguments: c,
            ),
          ),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _ensureLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _center = LatLng(pos.latitude, pos.longitude);
      _map?.animateCamera(CameraUpdate.newLatLng(_center));
    } catch (_) {
      // keep default center, offline fallback handled below.
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Map of Car Washes')),
      body: Stack(
        children: [
          const AppBackground(),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _mapAvailable
                  ? GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: _center, zoom: 12),
                      onMapCreated: (ctrl) => _map = ctrl,
                      myLocationButtonEnabled: true,
                      myLocationEnabled: true,
                      markers: _markers,
                      onCameraIdle: () {},
                      onCameraMoveStarted: () {},
                    )
                  : _offlineFallback(cs),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 0),
    );
  }

  Widget _offlineFallback(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: cs.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Map offline — showing list instead',
                  style: TextStyle(
                      color: cs.onSurface, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._carwashes.map(
          (m) => Card(
            child: ListTile(
              leading: const Icon(Icons.local_car_wash_rounded),
              title: Text(m['name'] as String),
              subtitle: Text(m['address'] as String? ?? ''),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/customer/carwash',
                  arguments: m),
            ),
          ),
        ),
      ],
    );
  }
}
