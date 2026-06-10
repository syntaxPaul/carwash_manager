import 'package:flutter/material.dart';

// Animated, lightweight gradient background with soft "water" glows.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key});
  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withValues(
                        alpha: 0.05 + 0.03 * (1 - (t - 0.5).abs() * 2)),
                    cs.surface,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -100 + 12 * t,
                    left: -80 + 16 * (1 - t),
                    child: _GlowCircle(
                      color: cs.primaryContainer.withValues(alpha: 0.55),
                      size: 240,
                    ),
                  ),
                  Positioned(
                    bottom: -120 + 18 * (1 - t),
                    right: -90 + 14 * t,
                    child: _GlowCircle(
                      color: cs.secondaryContainer.withValues(alpha: 0.5),
                      size: 280,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
