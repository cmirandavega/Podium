import 'package:flutter/material.dart';

import '../theme.dart';
import 'podium_mark.dart';

/// Shared building blocks for the premium Podium look: cards, badges,
/// score text, probability bars, and avatars.

/// Rounded navy card with a hairline border. Tappable when [onTap] is set.
class PodiumCard extends StatelessWidget {
  const PodiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color = PodiumColors.field,
    this.borderColor = PodiumColors.line,
    this.radius = PodiumRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section title with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 36),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Small rounded label, e.g. "LIVE", "FINAL", "PLAYOFFS".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = PodiumColors.silver,
    this.background = PodiumColors.silverTint,
    this.dot = false,
  });

  /// Pulsing-red "LIVE" badge.
  const StatusPill.live({super.key})
      : label = 'LIVE',
        color = PodiumColors.dangerText,
        background = PodiumColors.dangerTint,
        dot = true;

  /// Gold badge for wins, champions, and highlights.
  const StatusPill.gold(this.label, {super.key})
      : color = PodiumColors.gold,
        background = PodiumColors.goldTint,
        dot = false;

  final String label;
  final Color color;
  final Color background;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PodiumRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold "P" coin, the Podium currency mark.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: PodiumColors.gold, shape: BoxShape.circle),
      child: Text(
        'P',
        style: PodiumText.score(size: size * 0.6, color: PodiumColors.navy),
      ),
    );
  }
}

/// Pill showing a Podium coin balance.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins, this.onTap});

  final int? coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: coins == null ? 'Coin balance loading' : '$coins Podium coins',
      button: onTap != null,
      child: Material(
        color: PodiumColors.field,
        shape: const StadiumBorder(side: BorderSide(color: PodiumColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(),
                const SizedBox(width: 8),
                Text(
                  coins == null ? '—' : formatCount(coins!),
                  style: PodiumText.score(size: 19, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal fill bar, e.g. a win probability. [value] is 0 to 1.
class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({
    super.key,
    required this.value,
    this.color = PodiumColors.gold,
    this.track = PodiumColors.line,
    this.height = 6,
  });

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) => Container(
        height: height,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(height),
        ),
        child: Container(
          width: box.maxWidth * v,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      ),
    );
  }
}

/// Two-sided bar for head-to-head games: gold for the left side, silver
/// for the right. [leftShare] is 0 to 1.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.leftShare, this.height = 8});

  final double leftShare;
  final double height;

  @override
  Widget build(BuildContext context) {
    final share = leftShare.isNaN ? 0.5 : leftShare.clamp(0.0, 1.0);
    final left = (share * 1000).round().clamp(1, 999);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(flex: left, child: const ColoredBox(color: PodiumColors.gold)),
            const SizedBox(width: 3),
            Expanded(flex: 1000 - left, child: const ColoredBox(color: PodiumColors.silver)),
          ],
        ),
      ),
    );
  }
}

/// Round avatar with up to two initials and an optional medal ring.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.ring = PodiumColors.line,
    this.ringWidth = 1.5,
    this.background = PodiumColors.navy,
    this.foreground = PodiumColors.silver,
  });

  final String name;
  final double size;
  final Color ring;
  final double ringWidth;
  final Color background;
  final Color foreground;

  static String initialsOf(String name) {
    final words = name
        .replaceAll('@', '')
        .split(RegExp(r'[\s_\-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: ringWidth),
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// Square icon in a tinted rounded box, used on tiles.
class TintedIcon extends StatelessWidget {
  const TintedIcon({
    super.key,
    required this.icon,
    this.color = PodiumColors.gold,
    this.background = PodiumColors.goldTint,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Compact tile for the quick-action grid on the home screen.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    this.color = PodiumColors.gold,
    this.tint = PodiumColors.goldTint,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      onTap: onTap,
      radius: PodiumRadii.tile + 2,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(icon: icon, color: color, background: tint, size: 36),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: PodiumColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Podium mark plus the PODIUM wordmark, for app bars and splash.
class PodiumWordmark extends StatelessWidget {
  const PodiumWordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Podium',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PodiumMark(scale: size / 48),
          SizedBox(width: size * 0.42),
          Text('PODIUM', style: PodiumText.wordmark(size: size)),
        ],
      ),
    );
  }
}

/// Square icon button with a card background, as in the app bars.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PodiumColors.field,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PodiumRadii.control),
          side: const BorderSide(color: PodiumColors.line),
        ),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: PodiumColors.chalk, semanticLabel: tooltip),
                if (badge)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: PodiumColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: PodiumColors.field, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state inside a card.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: PodiumColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 12450 -> "12,450".
String formatCount(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// 1284.6 -> "1,284.6".
String formatPoints(double p) {
  final whole = p.truncate();
  final tenth = ((p - whole).abs() * 10).round();
  if (tenth == 10) return formatPoints(whole + (p < 0 ? -1.0 : 1.0));
  return '${formatCount(whole)}.$tenth';
}
