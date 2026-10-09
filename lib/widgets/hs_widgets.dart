// lib/widgets/hs_widgets.dart
//
// Shared presentational pieces, tuned to the HomeSaaz web look
// (Bootstrap-flavoured cards, stat tiles, list rows).
import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Big bold screen heading, like the web `<h2>` on every list page.
class HsPageTitle extends StatelessWidget {
  const HsPageTitle(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: Hs.ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// White record card with the web's blue left accent bar.
/// Presses in slightly on tap for tactile feedback.
class HsListCard extends StatefulWidget {
  const HsListCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent = Hs.blue,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color accent;
  final EdgeInsets padding;

  @override
  State<HsListCard> createState() => _HsListCardState();
}

class _HsListCardState extends State<HsListCard> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: Hs.fast,
      curve: Hs.curve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Hs.surface,
          borderRadius: BorderRadius.circular(Hs.radius),
          border: Border(left: BorderSide(color: widget.accent, width: 3.5)),
          boxShadow: Hs.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Hs.radius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _set(true),
              onTapUp: (_) => _set(false),
              onTapCancel: () => _set(false),
              splashColor: widget.accent.withValues(alpha: .06),
              highlightColor: widget.accent.withValues(alpha: .04),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// One label / value line inside an [HsListCard] (web `.card-row`).
///
/// Pass [valueWidget] instead of relying on [value]'s plain-text rendering
/// when the web shows something richer in that cell (e.g. a coloured
/// badge) — [value] still drives the fallback-dash logic either way.
class HsRow extends StatelessWidget {
  const HsRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
    this.bold,
    this.labelWidth = 112,
    this.valueWidget,
    this.bottomDivider = false,
  });
  final String label;
  final Object? value;
  final Color? valueColor;
  final bool? bold;
  final double labelWidth;
  final Widget? valueWidget;

  /// Web `.card-row{border-bottom:1px solid #f5f5f5}` — pass true on every
  /// row except the last in a card.
  final bool bottomDivider;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || '$value'.trim().isEmpty) ? '-' : '$value';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: bottomDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Hs.hairline)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Hs.faint,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                valueWidget ??
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: (bold ?? false)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: valueColor ?? Hs.inkSoft,
                    height: 1.3,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of stat tiles (web: "Total Items / Low Stock / …").
class HsStatRow extends StatelessWidget {
  const HsStatRow(this.tiles, {super.key});
  final List<HsStat> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: Hs.gap),
            Expanded(child: _StatCard(tiles[i])),
          ],
        ],
      ),
    );
  }
}

class HsStat {
  const HsStat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.stat);
  final HsStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            stat.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: Hs.muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              stat.value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: stat.color ?? Hs.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded container for a filter/search block.
class HsPanel extends StatelessWidget {
  const HsPanel({super.key, required this.child, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      child: child,
    );
  }
}

/// Small status pill (Approved / Pending / …).
class HsPill extends StatelessWidget {
  const HsPill(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Square dashboard / hub tile — icon over an uppercase label.
/// Mirrors web `.hs-tile` / `.tile-media` / `.tile-label` exactly: a plain
/// single-colour (teal) icon, no coloured chip background.
class HsGridTile extends StatefulWidget {
  const HsGridTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.imageAsset,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  /// When set, a photo/logo asset replaces the plain icon glyph.
  final String? imageAsset;

  /// Per-tile accent border (web dashboard gives every tile its own pastel
  /// colour). Falls back to the plain grey outline when not set.
  final Color? borderColor;

  @override
  State<HsGridTile> createState() => _HsGridTileState();
}

class _HsGridTileState extends State<HsGridTile> {
  bool _down = false;
  // Only ever set by a mouse/trackpad (MouseRegion.onEnter never fires for
  // touch) — so this is a no-op on a phone and a real hover on desktop/web.
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.borderColor ?? Hs.teal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : (_hover ? 1.02 : 1),
        duration: Hs.fast,
        curve: Hs.curve,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.5,
          duration: Hs.fast,
          child: AnimatedContainer(
            duration: Hs.fast,
            curve: Hs.curve,
            decoration: BoxDecoration(
              color: _hover
                  ? Color.alphaBlend(accent.withValues(alpha: .08), Hs.surface)
                  : Hs.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.borderColor == null
                    ? const Color(0xFFCFCFCF)
                    : (_hover ? accent : accent.withValues(alpha: .75)),
                width: widget.borderColor == null ? 1 : 2.5,
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: .25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown: (_) => setState(() => _down = true),
                  onTapUp: (_) => setState(() => _down = false),
                  onTapCancel: () => setState(() => _down = false),
                  hoverColor: accent.withValues(alpha: .06),
                  splashColor: accent.withValues(alpha: .18),
                  highlightColor: accent.withValues(alpha: .10),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 130),
                    // Slightly tighter than before: the coloured border
                    // (2.5px vs the old plain 1px) eats a few extra pixels
                    // of the fixed-height cell a GridView tile gives this,
                    // and used to overflow by a few pixels there.
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 70,
                          child: widget.imageAsset == null
                              ? Icon(widget.icon, size: 42, color: Hs.teal)
                              : Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      widget.imageAsset!,
                                      width: 74,
                                      height: 74,
                                      fit: BoxFit.cover,
                                      // Decodes straight to this display
                                      // size instead of the full JPEG
                                      // (some of these are 500x500+) —
                                      // every tile on the dashboard list
                                      // does this at once, so it matters.
                                      cacheWidth: 148,
                                      cacheHeight: 148,
                                      errorBuilder: (_, __, ___) => Icon(
                                        widget.icon,
                                        size: 42,
                                        color: Hs.teal,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            letterSpacing: 0.2,
                            color: Hs.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades + slides a list item up as it first appears.
class HsAppear extends StatefulWidget {
  const HsAppear({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<HsAppear> createState() => _HsAppearState();
}

class _HsAppearState extends State<HsAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Hs.med,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Hs.curve,
  );

  @override
  void initState() {
    super.initState();
    final delay = (widget.index.clamp(0, 8)) * 40;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, (1 - _a.value) * 10),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
