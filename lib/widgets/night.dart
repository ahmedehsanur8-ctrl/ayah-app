import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'pattern.dart';

/// "Night & Gold" building blocks shared by every screen.

/// True when the phone asks for less motion (Android "Remove animations").
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// The faint gold girih (8-point star) pattern on night surfaces.
class GirihLayer extends StatelessWidget {
  const GirihLayer({super.key, this.cell = 52, this.opacity = 0.2});

  final double cell;
  final double opacity;

  @override
  Widget build(BuildContext context) =>
      PatternLayer(color: context.palette.gold, opacity: opacity, cell: cell);
}

/// Navy header for the main screens: girih pattern, white text, safe area on top.
///
/// [lip] draws the rounded top of the page sheet at the bottom, so the content
/// below looks like a sheet laid over the header.
class NightHeader extends StatelessWidget {
  const NightHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.child,
    this.lip = false,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 12, 20),
    this.safeTop = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;

  /// Icon buttons on the right (use [NightIconButton]).
  final List<Widget> actions;

  /// Content under the title (cards, countdown, chips …).
  final Widget? child;
  final bool lip;
  final EdgeInsetsGeometry padding;
  final bool safeTop;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = safeTop ? MediaQuery.paddingOf(context).top : 0.0;
    return Material(
      color: p.night,
      child: Stack(
        children: [
          const GirihLayer(),
          Padding(
            padding: EdgeInsets.only(top: top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null || actions.isNotEmpty || leading != null)
                        Row(
                          children: [
                            if (leading != null) ...[leading!, const SizedBox(width: 4)],
                            Expanded(
                              child: title == null
                                  ? const SizedBox()
                                  : Semantics(
                                      header: true,
                                      child: Text(title!, style: nightTitleStyle(p)),
                                    ),
                            ),
                            ...actions,
                          ],
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(color: p.onNightMuted, fontSize: 15, height: 1.45),
                        ),
                      ],
                      if (child != null) ...[const SizedBox(height: 14), child!],
                    ],
                  ),
                ),
                if (lip) const SheetLip(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Serif title on a night surface.
TextStyle nightTitleStyle(Palette p, {double size = 24}) =>
    titleStyle(p, size: size).copyWith(color: p.onNight, fontWeight: FontWeight.w700);

/// The rounded top edge of the page sheet, drawn at the bottom of a header.
class SheetLip extends StatelessWidget {
  const SheetLip({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    decoration: BoxDecoration(
      color: context.palette.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusL)),
    ),
  );
}

/// Icon button for night headers: white line icon, 48dp, with a label for
/// screen readers.
class NightIconButton extends StatelessWidget {
  const NightIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    color: context.palette.onNight,
    icon: Icon(icon),
  );
}

/// Back button for compact night headers.
class NightBackButton extends StatelessWidget {
  const NightBackButton({super.key});

  @override
  Widget build(BuildContext context) => NightIconButton(
    icon: Icons.arrow_back_rounded,
    tooltip: 'ফিরে যান',
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

/// Compact navy app bar for sub-pages that sit on a night theme (the reader).
class NightAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NightAppBar({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppBar(
      backgroundColor: p.night,
      foregroundColor: p.onNight,
      iconTheme: IconThemeData(color: p.onNight),
      actionsIconTheme: IconThemeData(color: p.onNight),
      toolbarHeight: 64,
      flexibleSpace: const GirihLayer(cell: 44, opacity: 0.16),
      leading: Navigator.of(context).canPop() ? const NightBackButton() : null,
      titleSpacing: Navigator.of(context).canPop() ? 0 : 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nightTitleStyle(p, size: 19),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.onNightMuted, fontSize: 14),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

/// The main button on a night surface: gold with navy text.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = FilledButton.styleFrom(
      backgroundColor: p.gold,
      foregroundColor: p.night,
      minimumSize: Size(expand ? double.infinity : minTouch, minTouch),
    );
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}

/// Path of two overlapping squares, one turned 45°: the 8-point star outline.
Path octagramPath(Offset c, double r) {
  Path square(double turn) {
    final path = Path();
    for (var k = 0; k < 4; k++) {
      final a = turn + math.pi / 4 + k * math.pi / 2;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  return Path()
    ..addPath(square(0), Offset.zero)
    ..addPath(square(math.pi / 4), Offset.zero);
}

class _OctagramPainter extends CustomPainter {
  _OctagramPainter(this.color, this.stroke, this.fill);

  final Color color;
  final double stroke;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke;
    final path = octagramPath(c, r);
    if (fill != null) canvas.drawPath(path, Paint()..color = fill!);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_OctagramPainter old) =>
      old.color != color || old.stroke != stroke || old.fill != fill;
}

/// Gold 8-point star outline with a number inside (surah and ayah numbers).
class StarBadge extends StatelessWidget {
  const StarBadge(this.label, {super.key, this.size = 40, this.onNight = false});

  /// Already in Bangla digits.
  final String label;
  final double size;

  /// On a night surface the number is gold; on light it is the darker gold text.
  final bool onNight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OctagramPainter(p.gold, size / 26, null),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * (label.length > 2 ? 0.2 : 0.16)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: size * (label.length > 2 ? 0.3 : 0.36),
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: onNight ? p.gold : p.goldText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small gold octagram used as an ornament (e.g. next to a card title).
class OctagramIcon extends StatelessWidget {
  const OctagramIcon({super.key, this.size = 20, this.filled = false});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OctagramPainter(p.gold, math.max(1.2, size / 14), filled ? p.gold : null),
      ),
    );
  }
}

/// A clean list row: emerald icon on a soft emerald square, title, subtitle,
/// chevron. At least 56 high; whole row is tappable with press feedback.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticsLabel,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lead = leading ?? (icon == null ? null : IconSquare(icon!));
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                          height: 1.35,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 14, color: p.muted, height: 1.4),
                        ),
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(Icons.chevron_right_rounded, color: p.muted)
                        : const SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Emerald line icon on a soft emerald rounded square.
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, {super.key, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.pill, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: p.primary, size: size * 0.55),
    );
  }
}

/// Rows on a surface with thin dividers between them (no heavy card look).
class ListSection extends StatelessWidget {
  const ListSection({super.key, required this.children, this.indent = 70});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusM),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: indent, color: p.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A small pill on a night surface (location, date …).
class NightPill extends StatelessWidget {
  const NightPill({super.key, required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.nightLine,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: p.gold),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.onNight),
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
