import 'package:flutter/material.dart';

import '../theme.dart';

/// ---------------------------------------------------------------------------
/// WashDesk widget kit.
///
/// The shared building blocks every screen composes from. If a screen needs
/// a card, header, empty state or metric tile, it comes from here — not
/// hand-rolled — so the whole app looks like one product.
/// ---------------------------------------------------------------------------

/// Section title with an optional trailing action ("Quick actions", "See all").
class WdSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const WdSectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Wd.s3),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Wd.primaryDeep),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one card container. Hairline border + soft ambient shadow.
class WdCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  const WdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Wd.s4),
    this.color = Wd.surface,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: Wd.cardRadius,
        border: Border.all(color: Wd.border),
        boxShadow: Wd.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Wd.cardRadius,
        child: card,
      ),
    );
  }
}

/// Unified metric tile. One visual language for every number in the app:
/// icon in a tinted chip, quiet label, tabular figure, small caption.
/// `emphasis: true` fills the card with the brand color for the headline
/// metric (e.g. Net result).
class WdStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final bool emphasis;

  const WdStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = emphasis ? Colors.white : Wd.ink;
    final fgMuted = emphasis ? Colors.white.withValues(alpha: 0.75) : Wd.inkMuted;

    return Container(
      padding: const EdgeInsets.all(Wd.s4),
      decoration: BoxDecoration(
        color: emphasis ? Wd.primary : Wd.surface,
        borderRadius: Wd.cardRadius,
        border: emphasis ? null : Border.all(color: Wd.border),
        boxShadow: Wd.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: emphasis
                  ? Colors.white.withValues(alpha: 0.16)
                  : Wd.primarySoft,
              borderRadius: Wd.chipRadius,
            ),
            child: Icon(icon,
                size: 20, color: emphasis ? Colors.white : Wd.primaryDeep),
          ),
          const Spacer(),
          Text(label, style: t.labelMedium?.copyWith(color: fgMuted)),
          const SizedBox(height: Wd.s1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: t.headlineSmall?.copyWith(
                color: fg,
                fontFeatures: Wd.tabularFigures,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: Wd.s1),
            Text(caption!, style: t.labelSmall?.copyWith(color: fgMuted)),
          ],
        ],
      ),
    );
  }
}

/// Navigation tile for quick actions. The label auto-shrinks instead of
/// wrapping mid-word ("Bookkeepi / ng" is gone for good).
class WdActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const WdActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WdCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Wd.s4, vertical: Wd.s4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Wd.primarySoft,
              borderRadius: Wd.chipRadius,
            ),
            child: Icon(icon, size: 21, color: Wd.primaryDeep),
          ),
          const SizedBox(width: Wd.s3),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: Wd.inkFaint),
        ],
      ),
    );
  }
}

/// Friendly empty state: icon, one-line title, short message, optional CTA.
/// Every list screen should use this instead of a bare Text.
class WdEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const WdEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Wd.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Wd.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: Wd.primaryDeep),
            ),
            const SizedBox(height: Wd.s4),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Wd.s2),
            Text(
              message,
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Wd.s5),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft callout that nudges the owner toward an opportunity
/// (e.g. "3 free washes ready to redeem").
class WdNudgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  const WdNudgeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.background = Wd.successSoft,
    this.foreground = Wd.success,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Wd.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(Wd.s4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: Wd.cardRadius,
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 26),
              const SizedBox(width: Wd.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.titleSmall?.copyWith(color: foreground)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: t.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
