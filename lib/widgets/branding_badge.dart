import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

class BrandingBadge extends StatefulWidget {
  const BrandingBadge({super.key});

  @override
  State<BrandingBadge> createState() => _BrandingBadgeState();
}

class _BrandingBadgeState extends State<BrandingBadge> {
  bool _hasLogo = false;

  @override
  void initState() {
    super.initState();
    _checkForLogo();
  }

  Future<void> _checkForLogo() async {
    try {
      await rootBundle.load('assets/branding/roim4ads.png');
      if (mounted) {
        setState(() => _hasLogo = true);
      }
    } catch (_) {
      // Logo not present yet; keep fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _hasLogo
                ? Image.asset(
                    'assets/branding/roim4ads.png',
                    height: 56,
                    width: 56,
                    fit: BoxFit.cover,
                  )
                : SvgPicture.asset(
                    'assets/branding/roim4ads_placeholder.svg',
                    height: 56,
                    width: 56,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built by roim4ads',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_outward, color: cs.primary),
        ],
      ),
    );
  }
}
