import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/customer_auth.dart';
import '../../services/review_service.dart';
import '../../utils/format.dart';
import '../../widgets/app_background.dart';
import '../../widgets/branding_badge.dart';
import '../../widgets/customer_nav.dart';

class CarwashDetailScreen extends StatefulWidget {
  const CarwashDetailScreen({super.key});

  @override
  State<CarwashDetailScreen> createState() => _CarwashDetailScreenState();
}

class _CarwashDetailScreenState extends State<CarwashDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  final DateFormat _dateFmt = DateFormat('MMM d, yyyy • HH:mm');
  late Map<String, Object?> _carwash;
  late List<Map<String, dynamic>> _services;
  double? _fromPrice;
  bool _initialized = false;

  List<Map<String, Object?>> _reviews = [];
  double? _avgRating;
  int _reviewCount = 0;
  bool _loadingReviews = false;
  bool _submitting = false;
  int _selectedRating = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final m =
        ModalRoute.of(context)!.settings.arguments as Map<String, Object?>;
    _carwash = m;
    _services = (json.decode(m['services_json'] as String) as List)
        .cast<Map<String, dynamic>>();
    _fromPrice = _services.isEmpty
        ? null
        : (_services.first['price'] as num?)?.toDouble();
    _initialized = true;
    _loadReviews();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
    });
    try {
      final carwashId = _carwash['id'] as String;
      final summary = await ReviewService.instance.summaryForCarwash(carwashId);
      final items =
          await ReviewService.instance.reviewsForCarwash(carwashId, limit: 30);
      setState(() {
        _avgRating = summary['avg'] as double?;
        _reviewCount = summary['count'] as int? ?? 0;
        _reviews = items;
      });
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _submitReview() async {
    if (_submitting) return;
    final rating = _selectedRating.clamp(1, 5);
    final comment = _commentCtrl.text.trim();
    setState(() => _submitting = true);
    try {
      final customer = CustomerAuth.instance.current;
      await ReviewService.instance.addReview(
        carwashId: _carwash['id'] as String,
        rating: rating,
        comment: comment.isEmpty ? null : comment,
        customerId: customer?.id,
        customerName: customer?.name,
      );
      _commentCtrl.clear();
      setState(() {
        _selectedRating = 5;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for rating this car wash!')),
        );
      }
      await _loadReviews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(_carwash['name'] as String)),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.9),
                      cs.secondaryContainer.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: cs.primary.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 18)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _carwash['name'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (_carwash['address'] ?? '') as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: cs.onPrimaryContainer
                                        .withValues(alpha: 0.85)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _pill(
                                  cs,
                                  Icons.schedule,
                                  _carwash['open_hours'] == null
                                      ? 'Hours not listed'
                                      : _carwash['open_hours'] as String),
                              if (_fromPrice != null)
                                _pill(cs, Icons.payments_outlined,
                                    'From ${money(_fromPrice!)}'),
                              if (_carwash['queue_length'] != null)
                                _pill(cs, Icons.timer_outlined,
                                    'Queue: ${_carwash['queue_length']} ahead'),
                              if (_carwash['avg_wash_mins'] != null)
                                _pill(cs, Icons.timelapse_rounded,
                                    'Avg ${_carwash['avg_wash_mins']} mins'),
                              _pill(cs, Icons.shield_moon_outlined,
                                  'Trusted partner'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.local_car_wash_rounded,
                          color: cs.primary, size: 34),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double halfWidth =
                      (constraints.maxWidth - 12) / 2; // spacing accounted for
                  final double fullWidth = constraints.maxWidth;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: halfWidth,
                            child: _infoIcon(
                              cs,
                              Icons.call,
                              _carwash['phone'] as String? ?? 'N/A',
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: _infoIcon(
                              cs,
                              Icons.pin_drop_outlined,
                              (_carwash['code'] ?? 'CW') as String,
                            ),
                          ),
                          SizedBox(
                            width: fullWidth,
                            child: _infoIcon(
                              cs,
                              Icons.place,
                              _carwash['address'] as String? ??
                                  'Address pending',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Services & pricing',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Upfront, no surprises',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              ..._services.map(
                (s) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(s['name'] as String),
                    subtitle: const Text('Includes vacuum and interior wipe'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(money((s['price'] as num).toDouble()),
                          style: TextStyle(color: cs.onPrimaryContainer)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('What to expect'),
                  subtitle: Text(
                      'Share your booking code on arrival. Most washes respond in 10 minutes and keep you updated via SMS.'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/customer/book',
                  arguments: _carwash,
                ),
                icon: const Icon(Icons.event_available),
                label: const Text('Pre‑book a Wash'),
              ),
              const SizedBox(height: 20),
              _ratingsSection(context, cs),
              const SizedBox(height: 16),
              const BrandingBadge(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 0),
    );
  }

  Widget _ratingsSection(BuildContext context, ColorScheme cs) {
    final avgText =
        _avgRating == null ? 'No ratings yet' : _avgRating!.toStringAsFixed(1);
    final subtitle = _reviewCount == 0
        ? 'Be the first to leave a review'
        : 'Based on $_reviewCount visit${_reviewCount == 1 ? '' : 's'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ratings & feedback',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Icon(Icons.reviews_outlined, color: cs.primary),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      avgText,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: cs.onPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < (_avgRating ?? 0).round()
                              ? Icons.star
                              : Icons.star_border,
                          color: cs.onPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share how the wash went to help other drivers book with confidence.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _reviewComposer(cs),
        const SizedBox(height: 12),
        _loadingReviews
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
                ? Text(
                    'No reviews yet — add yours above.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  )
                : Column(
                    children: _reviews
                        .map((r) => _reviewCard(context, cs, r))
                        .toList(),
                  ),
      ],
    );
  }

  Widget _reviewComposer(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate your experience',
              style:
                  TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (i) {
                  final score = i + 1;
                  final active = score <= _selectedRating;
                  return IconButton(
                    onPressed: () => setState(() => _selectedRating = score),
                    icon: Icon(
                      active ? Icons.star_rounded : Icons.star_border_rounded,
                      color: active ? cs.primary : cs.onSurfaceVariant,
                      size: 28,
                    ),
                  );
                },
              ),
            ),
            TextField(
              controller: _commentCtrl,
              minLines: 2,
              maxLines: 4,
              maxLength: 180,
              decoration: const InputDecoration(
                hintText: 'Leave a short comment (optional)',
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitReview,
                icon: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Saving...' : 'Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(
      BuildContext context, ColorScheme cs, Map<String, Object?> row) {
    final rating = (row['rating'] as num).toInt();
    final comment = row['comment'] as String?;
    final ts = row['ts'] as int;
    final customer = (row['customer_name'] as String?) ?? 'Customer';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: cs.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customer,
                    style: TextStyle(
                        color: cs.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _dateFmt.format(DateTime.fromMillisecondsSinceEpoch(ts)),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  color: cs.secondary,
                  size: 18,
                ),
              ),
            ),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                comment,
                style: TextStyle(
                    color: cs.onSurface, height: 1.3, letterSpacing: 0.1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(ColorScheme cs, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cs.onPrimaryContainer, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoIcon(ColorScheme cs, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
