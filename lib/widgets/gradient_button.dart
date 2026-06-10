import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  const GradientButton(
      {super.key, required this.onPressed, required this.child, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradient = LinearGradient(
      colors: [cs.primary, cs.secondary],
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: cs.onPrimary),
          const SizedBox(width: 8),
        ],
        DefaultTextStyle(
          style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
          child: child,
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: cs.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: content,
          ),
        ),
      ),
    );
  }
}
