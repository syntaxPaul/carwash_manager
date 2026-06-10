import 'package:flutter/material.dart';
import '../data/settings.dart';

class WaveHeader extends StatelessWidget {
  final String subtitle;
  const WaveHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer,
            cs.secondaryContainer.withValues(alpha: 0.8)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned.fill(
              child:
                  _Waves(color: cs.onPrimaryContainer.withValues(alpha: 0.06))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.businessName,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Waves extends StatelessWidget {
  final Color color;
  const _Waves({required this.color});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WavePainter(color),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    Path w1 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.6,
          size.width * 0.5, size.height * 0.75)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.9, size.width, size.height * 0.8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(w1, p);

    final p2 = Paint()..color = color.withValues(alpha: 0.6);
    Path w2 = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.7, size.width * 0.6,
          size.height * 0.85)
      ..quadraticBezierTo(
          size.width * 0.85, size.height, size.width, size.height * 0.9)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(w2, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
