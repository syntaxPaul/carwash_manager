import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/db.dart';
import '../../models/customer.dart';
import '../../services/customer_auth.dart';
import '../../utils/format.dart';
import '../../widgets/customer_nav.dart';
import '../../widgets/app_background.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  Position? _pos;
  String _query = '';
  List<Map<String, Object?>> _items = [];
  List<Map<String, Object?>> _vehicles = [];
  bool _locating = false;
  String? _locationError;
  bool _showPretoriaMocks = false;
  Map<String, double>? _mockOrigin;
  late final ValueListenable<Customer?> _authListenable;

  @override
  void initState() {
    super.initState();
    _authListenable = CustomerAuth.instance.listenable;
    _authListenable.addListener(_handleAuthChange);
    _bootstrap();
    _detectLocation();
  }

  @override
  void dispose() {
    _authListenable.removeListener(_handleAuthChange);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _ensureSeed();
    } finally {
      await _load();
      await _loadVehicles();
    }
  }

  void _handleAuthChange() {
    _loadVehicles();
  }

  Future<void> _ensureSeed() async {
    final d = await AppDb.instance.db;
    final c = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) FROM carwashes'));
    if ((c ?? 0) > 0) return;
    try {
      final data = await rootBundle.loadString('assets/carwashes.json');
      final arr = (json.decode(data) as List).cast<Map<String, dynamic>>();
      if (arr.isEmpty) {
        await _insertFallbackCarwash(d);
        return;
      }
      final batch = d.batch();
      for (final m in arr) {
        batch.insert(
            'carwashes',
            {
              'id': m['id'],
              'code': m['code'],
              'name': m['name'],
              'lat': m['lat'],
              'lng': m['lng'],
              'address': m['address'],
              'phone': m['phone'],
              'open_hours': m['open_hours'],
              'services_json': json.encode(m['services']),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    } catch (_) {
      await _insertFallbackCarwash(d);
    }
  }

  Future<void> _insertFallbackCarwash(DatabaseExecutor d) async {
    const demo = {
      'id': 'cw_demo_site',
      'code': 'DEMO',
      'name': 'Demo Downtown Wash',
      'lat': -26.2041,
      'lng': 28.0473,
      'address': '1 Demo Street, Johannesburg',
      'phone': '+27 11 555 0000',
      'open_hours': 'Mon–Sun 08:00–18:00',
      'services': [
        {'name': 'Full wash', 'price': 150},
        {'name': 'Exterior only', 'price': 90},
      ],
    };
    await d.insert(
        'carwashes',
        {
          'id': demo['id'],
          'code': demo['code'],
          'name': demo['name'],
          'lat': demo['lat'],
          'lng': demo['lng'],
          'address': demo['address'],
          'phone': demo['phone'],
          'open_hours': demo['open_hours'],
          'services_json': json.encode(demo['services']),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  List<Map<String, Object?>> _buildPretoriaMocks() {
    return [
      {
        'id': 'mock_pta_core',
        'code': 'PTA-CBD',
        'name': 'Pretoria Shine Hub',
        'lat': -25.7479,
        'lng': 28.2293,
        'address': 'Church Square, Pretoria',
        'phone': '+27 12 555 1100',
        'open_hours': 'Mon-Sun 07:30-18:30',
        'services_json': json.encode([
          {'name': 'Express exterior', 'price': 120},
          {'name': 'Deep clean sedan', 'price': 240},
          {'name': 'Detail add-ons', 'price': 320},
        ]),
        'queue_length': 2,
        'avg_wash_mins': 35,
      },
      {
        'id': 'mock_annlin_main',
        'code': 'ANNLIN',
        'name': 'Annlin Auto Spa',
        'lat': -25.6647,
        'lng': 28.2066,
        'address': 'Rachele Street, Annlin',
        'phone': '+27 12 555 2211',
        'open_hours': 'Mon-Sat 07:00-19:00',
        'services_json': json.encode([
          {'name': 'SUV foam wash', 'price': 180},
          {'name': 'Interior refresh', 'price': 210},
          {'name': 'Premium valet', 'price': 320},
        ]),
        'queue_length': 1,
        'avg_wash_mins': 30,
      },
      {
        'id': 'mock_riviera_lane',
        'code': 'RIVIERA',
        'name': 'Riviera Quick Wash',
        'lat': -25.7383,
        'lng': 28.2211,
        'address': 'Riviera Road, Pretoria',
        'phone': '+27 12 555 4433',
        'open_hours': 'Mon-Sun 08:00-18:00',
        'services_json': json.encode([
          {'name': 'Touchless rinse', 'price': 110},
          {'name': 'Mini valet', 'price': 190},
          {'name': 'Clay & wax', 'price': 280},
        ]),
        'queue_length': 3,
        'avg_wash_mins': 28,
      },
    ];
  }

  Future<void> _detectLocation({bool injectPretoriaMocks = false}) async {
    setState(() {
      _locating = true;
      _locationError = null;
      if (!injectPretoriaMocks) {
        _showPretoriaMocks = false;
        _mockOrigin = null;
      }
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied.';
        });
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError =
              'Turn on location services to see nearby car washes.';
        });
        return;
      }
      final Position p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _pos = p;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Could not determine your location. Please try again.';
      });
    } finally {
      final bool wasMounted = mounted;
      if (injectPretoriaMocks && wasMounted) {
        setState(() {
          _showPretoriaMocks = true;
          _mockOrigin = const {'lat': -25.7479, 'lng': 28.2293};
        });
      }
      if (wasMounted) {
        setState(() {
          _locating = false;
        });
        await _load();
        if (mounted && injectPretoriaMocks) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pretoria & Annlin demo car washes added.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _load() async {
    final double? originLat =
        _mockOrigin != null ? _mockOrigin!['lat'] : _pos?.latitude;
    final double? originLng =
        _mockOrigin != null ? _mockOrigin!['lng'] : _pos?.longitude;

    final d = await AppDb.instance.db;
    final rows = await d.query('carwashes');
    final list = rows.map((m) {
      final lat = (m['lat'] as num).toDouble();
      final lng = (m['lng'] as num).toDouble();
      double? km;
      if (originLat != null && originLng != null) {
        km = _haversine(originLat, originLng, lat, lng);
      }
      return {...m, 'km': km};
    }).toList();

    if (_showPretoriaMocks) {
      for (final m in _buildPretoriaMocks()) {
        final lat = (m['lat'] as num).toDouble();
        final lng = (m['lng'] as num).toDouble();
        double? km;
        if (originLat != null && originLng != null) {
          km = _haversine(originLat, originLng, lat, lng);
        }
        list.add({...m, 'km': km});
      }
    }

    list.sort((a, b) {
      final ka = a['km'] as double?;
      final kb = b['km'] as double?;
      if (ka == null && kb == null) {
        return (a['name'] as String).compareTo(b['name'] as String);
      }
      if (ka == null) return 1;
      if (kb == null) return -1;
      return ka.compareTo(kb);
    });
    if (!mounted) return;
    setState(() => _items = list);
  }

  Future<void> _loadVehicles() async {
    final customer = CustomerAuth.instance.current;
    if (customer == null) {
      setState(() => _vehicles = []);
      return;
    }
    final db = await AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
      SELECT v.*, c.name AS carwash_name, c.id AS carwash_id, c.address AS carwash_address,
             c.phone AS carwash_phone, c.open_hours AS carwash_open_hours,
             c.services_json AS services_json, c.code AS carwash_code,
             c.lat AS carwash_lat, c.lng AS carwash_lng
      FROM vehicles v
      LEFT JOIN carwashes c ON c.id = v.carwash_id
      WHERE v.customer_id = ?
      ORDER BY v.created_ts DESC
      ''',
      [customer.id],
    );
    setState(() => _vehicles = rows);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180);

  Widget _heroSection(
      BuildContext context, List<Map<String, Object?>> filtered) {
    final cs = Theme.of(context).colorScheme;
    final usingMock = _showPretoriaMocks;
    final hasLocation = _pos != null || _mockOrigin != null;
    final status = _locationError ??
        (usingMock
            ? 'Pretoria & Annlin demo picks are pinned below.'
            : hasLocation
                ? 'Distances sorted using your latest location.'
                : 'Refresh to surface washes around you.');
    final badgeLabel = usingMock
        ? 'Pretoria demo'
        : hasLocation
            ? 'Live nearby'
            : 'Location off';
    final badgeColor = usingMock
        ? cs.secondaryContainer
        : hasLocation
            ? cs.onPrimary.withValues(alpha: 0.16)
            : cs.surface.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.82),
            cs.secondary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 30,
            offset: const Offset(0, 24),
            color: cs.primary.withValues(alpha: 0.28),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -18,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onPrimary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.onPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_car_wash_rounded,
                                  size: 18, color: cs.onPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'Find a wash',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: cs.onPrimary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Fresh wheels, zero hassle.',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lock in vetted Pretoria and Annlin spots with upfront pricing, live queues, and your go-to services.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: cs.onPrimary.withValues(alpha: 0.9),
                                  height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 190,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: cs.onPrimary,
                                  foregroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _locating
                                    ? null
                                    : () => _detectLocation(
                                        injectPretoriaMocks: true),
                                icon: _locating
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.primary,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _pos == null && !usingMock
                                      ? 'Refresh location'
                                      : 'Refresh nearby',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/customer/map'),
                              icon: const Icon(Icons.explore_outlined),
                              label: const Text('Open map'),
                              style: FilledButton.styleFrom(
                                foregroundColor: cs.onPrimary,
                                backgroundColor:
                                    cs.onPrimary.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: cs.onPrimary.withValues(alpha: 0.08),
                          child: SvgPicture.asset(
                            'assets/illustrations/customer_locator.svg',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: cs.onPrimary.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            color: cs.onPrimary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            usingMock
                                ? 'Pretoria • Annlin demo pins'
                                : hasLocation
                                    ? 'Using your latest coordinates'
                                    : 'Location idle',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: cs.onPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: cs.onPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _locationError != null
                                ? cs.onErrorContainer
                                : cs.onPrimary.withValues(alpha: 0.9),
                          ),
                    ),
                    if (usingMock) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildPretoriaMocks()
                            .map(
                              (m) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: cs.onPrimary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_car_wash,
                                        size: 16, color: cs.onPrimary),
                                    const SizedBox(width: 6),
                                    Text(
                                      (m['name'] ?? '') as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: cs.onPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_locating) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Refreshing nearby picks...',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (filtered.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 18, color: cs.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby picks',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onPrimary, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      'Tap to book',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: math.min(filtered.length, 4),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) => _heroCarwashCard(ctx, filtered[i]),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _statusPill(
                      color: _locationError != null
                          ? cs.errorContainer.withValues(alpha: 0.5)
                          : cs.surface.withValues(alpha: 0.16),
                      iconColor: _locationError != null
                          ? cs.onErrorContainer
                          : cs.onPrimary,
                      icon: _locationError != null
                          ? Icons.error_outline
                          : Icons.radar_rounded,
                      label: status),
                  _statusPill(
                      color: cs.surface.withValues(alpha: 0.18),
                      iconColor: cs.onPrimary,
                      icon: Icons.bolt_outlined,
                      label: 'Upfront pricing & instant codes'),
                  _statusPill(
                      color: cs.surface.withValues(alpha: 0.18),
                      iconColor: cs.onPrimary,
                      icon: Icons.route_rounded,
                      label: 'Pretoria + Annlin lineup'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      _QuickActionData(
        icon: Icons.explore_rounded,
        title: 'Plan on the map',
        subtitle: 'Pretoria and Annlin pins side by side with live queues.',
        badge: 'Map',
        ctaLabel: 'Open map',
        color: cs.primaryContainer,
        onTap: () => Navigator.pushNamed(context, '/customer/map'),
      ),
      _QuickActionData(
        icon: Icons.local_shipping_outlined,
        title: 'Track a wash',
        subtitle: 'Watch progress in real time and share ETAs.',
        badge: 'Live',
        ctaLabel: 'Track status',
        color: cs.secondaryContainer,
        onTap: () => Navigator.pushNamed(context, '/customer/track'),
      ),
      _QuickActionData(
        icon: Icons.loyalty_rounded,
        title: 'View rewards',
        subtitle: 'Punch cards, streaks, and rewards in one place.',
        badge: 'Perks',
        ctaLabel: 'View rewards',
        color: cs.tertiaryContainer,
        onTap: () => Navigator.pushNamed(context, '/customer/rewards'),
      ),
      _QuickActionData(
        icon: Icons.history_rounded,
        title: 'Booking history',
        subtitle: 'Find receipts, notes, and repeat a past service.',
        badge: 'History',
        ctaLabel: 'Open history',
        color: cs.surfaceContainerHighest,
        onTap: () => Navigator.pushNamed(context, '/customer/history'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool twoColumns = constraints.maxWidth >= 520;
        final double tileWidth =
            twoColumns ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: actions
              .map(
                (a) => SizedBox(
                  width: tileWidth,
                  child: _QuickActionCard(data: a),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _welcomeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    Widget? leading,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListTile(
          leading: leading ??
              CircleAvatar(
                backgroundColor: cs.onPrimary.withValues(alpha: 0.12),
                foregroundColor: cs.onPrimary,
                child: const Icon(Icons.emoji_events_outlined),
              ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                ),
          ),
          trailing: FilledButton.tonalIcon(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onPressed,
            label: Text(buttonLabel),
          ),
        ),
      ),
    );
  }

  Widget _heroCarwashCard(BuildContext context, Map<String, Object?> m) {
    final cs = Theme.of(context).colorScheme;
    final km = m['km'] as double?;
    final services = m['services_json'] as String?;
    final decoded = services == null
        ? const []
        : (json.decode(services) as List).cast<dynamic>();
    final primary =
        decoded.isEmpty ? null : decoded.first as Map<String, dynamic>;
    final firstService = primary?['name']?.toString();
    final firstPrice = primary?['price'] as num?;
    return SizedBox(
      width: 230,
      child: Material(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            '/customer/carwash',
            arguments: m,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        km == null ? '— km' : '${km.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (m['address'] ?? '') as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.local_car_wash_rounded,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        firstService != null
                            ? (firstPrice != null
                                ? '$firstService • ${money(firstPrice.toDouble())}'
                                : firstService)
                            : 'Upfront pricing ready',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pick',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: cs.primary),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.north_east_rounded,
                              size: 16, color: cs.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _carwashCard(BuildContext context, Map<String, Object?> m) {
    final cs = Theme.of(context).colorScheme;
    final km = m['km'] as double?;
    final services = m['services_json'] as String?;
    final decoded =
        services == null ? [] : (json.decode(services) as List).cast<dynamic>();
    final primaryService =
        decoded.isEmpty ? null : decoded.first as Map<String, dynamic>;
    final firstService = primaryService?['name']?.toString();
    final firstPrice = primaryService?['price'] as num?;
    final queueLen = m['queue_length'] as int?;
    final avgMins = m['avg_wash_mins'] as int?;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.pushNamed(
          context,
          '/customer/carwash',
          arguments: m,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.local_car_wash_rounded,
                        color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                m['name'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.2),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                km == null
                                    ? '— km'
                                    : '${km.toStringAsFixed(1)} km',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (m['address'] ?? '') as String,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 18, color: cs.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                (m['open_hours'] ?? 'Hours not listed')
                                    as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (firstService != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        firstPrice != null
                            ? '$firstService • ${money(firstPrice.toDouble())}'
                            : firstService,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: cs.onSecondaryContainer),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Text('Upfront pricing',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: cs.onSurface)),
                      ],
                    ),
                  ),
                ],
              ),
              if (queueLen != null || avgMins != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (queueLen != null)
                      _pill(
                          context, Icons.timer_outlined, '$queueLen in queue'),
                    if (avgMins != null)
                      _pill(context, Icons.timelapse_rounded,
                          'Avg $avgMins mins'),
                  ],
                ),
              ],
              if (decoded.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: decoded
                      .take(3)
                      .map(
                        (s) => Chip(
                          label: Text((s['name'] ?? '') as String),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, Map<String, Object?> row) {
    final cs = Theme.of(context).colorScheme;
    final hasCarwash = row['carwash_id'] != null && row['carwash_name'] != null;
    final vehicleLabel = _formatVehicleRow(row);
    final carwashName = (row['carwash_name'] as String?) ?? 'No carwash linked';
    final service = row['preferred_service'] as String?;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicleLabel,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            carwashName,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (service != null && service.isNotEmpty) ...[
            const SizedBox(height: 6),
            Chip(
              avatar: const Icon(Icons.local_car_wash, size: 16),
              label: Text(service),
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: hasCarwash ? () => _quickBookVehicle(row) : null,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Book now'),
          ),
        ],
      ),
    );
  }

  String _formatVehicleRow(Map<String, Object?> row) {
    final parts = [
      row['make'] as String?,
      row['model'] as String?,
      (row['year'] as int?)?.toString(),
      row['license_plate'] as String?,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Vehicle' : parts.join(' • ');
  }

  Future<void> _quickBookVehicle(Map<String, Object?> row) async {
    final carwashId = row['carwash_id'] as String?;
    if (carwashId == null) return;
    final db = await AppDb.instance.db;
    final carwashRows = await db.query(
      'carwashes',
      where: 'id = ?',
      whereArgs: [carwashId],
      limit: 1,
    );
    if (carwashRows.isEmpty) return;
    final carwash = carwashRows.first;
    final prefill = {
      'customer_name': CustomerAuth.instance.current?.name,
      'phone': CustomerAuth.instance.current?.phone,
      'vehicle': _formatVehicleRow(row),
      'service': row['preferred_service'],
      'appt_ts':
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
    };
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/customer/book',
      arguments: {
        ...carwash,
        'prefill': prefill,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((m) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return (m['name'] as String).toLowerCase().contains(q) ||
          (m['address'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Find a Car Wash')),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 154),
            children: [
              _heroSection(context, filtered),
              const SizedBox(height: 16),
              ValueListenableBuilder<Customer?>(
                valueListenable: CustomerAuth.instance.listenable,
                builder: (context, customer, _) {
                  if (customer == null) {
                    return _welcomeCard(
                      context,
                      title: 'Sign in to collect punches',
                      subtitle:
                          'Track visits and unlock rewards every time you book.',
                      buttonLabel: 'Sign in',
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/customer/history',
                      ),
                    );
                  }
                  final trimmed = customer.name.trim();
                  final firstName = trimmed.isEmpty
                      ? customer.name
                      : trimmed.split(' ').first;
                  return _welcomeCard(
                    context,
                    title: 'Welcome back, $firstName',
                    subtitle: 'Tap to view your rewards and recent washes.',
                    buttonLabel: 'My rewards',
                    onPressed: () =>
                        Navigator.pushNamed(context, '/customer/rewards'),
                    leading: CircleAvatar(
                      child: Text(
                        customer.name.isEmpty
                            ? '?'
                            : customer.name[0].toUpperCase(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(
                        alpha: 0.95,
                      ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search by name, suburb or service',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () => setState(() => _query = ''),
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 18),
              _sectionHeader(
                context,
                'Quick actions',
                subtitle: 'Control every booking in one tap',
              ),
              const SizedBox(height: 10),
              _quickActions(context),
              if (_vehicles.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionHeader(
                  context,
                  'Saved vehicles',
                  subtitle: 'One-tap booking with your preferred service',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) => _vehicleCard(ctx, _vehicles[i]),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.travel_explore,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        const Text(
                            'No car washes match your search right now.'),
                        const SizedBox(height: 6),
                        const Text(
                          'Try another suburb or refresh your location to widen the results.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _sectionHeader(
                  context,
                  'Nearby spots',
                  subtitle: _showPretoriaMocks || _mockOrigin != null
                      ? 'Pretoria & Annlin demo lineup refreshed from the mock location'
                      : _pos == null
                          ? 'Sorted alphabetically until we have your location'
                          : 'Closest partners first with upfront pricing',
                ),
                const SizedBox(height: 12),
                ...filtered.map((m) => _carwashCard(context, m)),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 0),
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String ctaLabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.ctaLabel,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: data.onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              data.color.withValues(alpha: 0.9),
              cs.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: cs.onSurface),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.badge,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  data.ctaLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: data.color),
                ),
                const SizedBox(width: 6),
                Icon(Icons.north_east, size: 18, color: data.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
