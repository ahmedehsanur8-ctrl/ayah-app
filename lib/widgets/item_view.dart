import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';
import '../services/audio.dart';
import 'audio_button.dart';
import 'category_style.dart';
import 'pattern.dart';
import 'share_card.dart';

/// Arabic text, right-to-left, in the Amiri Quran font.
class ArabicText extends StatelessWidget {
  const ArabicText(this.text, {super.key, this.size = 26, this.maxLines, this.color});

  final String text;
  final double size;
  final int? maxLines;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
    final p = context.palette;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: arabicFont,
            fontSize: size * settings.textScale,
            height: 2.05,
            color: color ?? p.arabic,
          ),
        ),
      ),
    );
  }
}

/// Bangla text in Noto Sans Bengali.
class BanglaText extends StatelessWidget {
  const BanglaText(
    this.text, {
    super.key,
    this.size = 17,
    this.maxLines,
    this.color,
    this.align = TextAlign.start,
    this.weight,
  });

  final String text;
  final double size;
  final int? maxLines;
  final Color? color;
  final TextAlign align;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
    final p = context.palette;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: banglaFont,
          fontFamilyFallback: fontFallback,
          fontSize: size * settings.textScale,
          height: 1.7,
          fontWeight: weight,
          color: color ?? p.text,
        ),
      ),
    );
  }
}

/// Small coloured pill with the category icon and name.
class CategoryChip extends StatelessWidget {
  const CategoryChip(this.item, {super.key, this.onDark = false});

  final ContentItem item;

  /// Use light colours for a dark (green) background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = CategoryStyle.of(item.categoryId);
    final fg = onDark ? Brand.lightGold : style.foreground(p);
    final bg = onDark ? Colors.white.withValues(alpha: 0.12) : style.background(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${item.isAyah ? 'আয়াত' : 'হাদিস'} · ${item.category}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: headingFont,
                fontSize: 14,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin line with a small eight-pointed star in the middle.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.accent;
    Widget line(List<Color> colors) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          line([c.withValues(alpha: 0), c.withValues(alpha: 0.6)]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox.square(dimension: 14, child: CustomPaint(painter: StarPainter(c))),
          ),
          line([c.withValues(alpha: 0.6), c.withValues(alpha: 0)]),
        ],
      ),
    );
  }
}

class StarPainter extends CustomPainter {
  StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      eightPointStar(size.center(Offset.zero), size.width / 2),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(StarPainter old) => old.color != color;
}

/// Heart button that saves / un-saves an item.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton(this.item, {super.key, this.color});

  final ContentItem item;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final fav = settings.isFavorite(item.id);
        return IconButton(
          tooltip: fav ? 'প্রিয় থেকে সরান' : 'প্রিয়তে রাখুন',
          onPressed: () {
            settings.toggleFavorite(item.id);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(
                    fav ? 'প্রিয় তালিকা থেকে সরানো হয়েছে' : 'প্রিয় তালিকায় রাখা হয়েছে',
                  ),
                ),
              );
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(
              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(fav),
              color: fav ? context.palette.heart : (color ?? context.palette.muted),
            ),
          ),
        );
      },
    );
  }
}

/// Play / stop the Arabic recitation (ayah) or the Bangla voice (hadith).
class ItemAudioButton extends StatelessWidget {
  const ItemAudioButton(this.item, {super.key, this.color, this.label});

  final ContentItem item;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) => AudioButton(
    id: item.id,
    color: color,
    label: label,
    onToggle: () => AudioController.instance.toggleItem(item),
  );
}

/// Button that opens the share-as-image sheet.
class ShareButton extends StatelessWidget {
  const ShareButton(this.item, {super.key, this.color});

  final ContentItem item;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'ছবি হিসেবে শেয়ার করুন',
      onPressed: () => showShareSheet(context, item),
      icon: Icon(Icons.share_rounded, color: color ?? context.palette.muted),
    );
  }
}

/// The full text of an item: Arabic, Bangla, reference and note.
class ItemBody extends StatelessWidget {
  const ItemBody(this.item, {super.key});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArabicText(item.arabic, size: item.isAyah ? 31 : 25),
        const OrnamentDivider(),
        BanglaText(item.bangla, size: 18),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BanglaText(item.title, size: 14.5, color: p.primary, weight: FontWeight.w700),
                  if (item.subtitle.isNotEmpty)
                    BanglaText(item.subtitle, size: 12.5, color: p.muted),
                ],
              ),
            ),
          ],
        ),
        if (item.placeholder)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: BanglaText('কিছু লেখা ডাউনলোড করা যায়নি।', size: 13, color: Colors.red),
          ),
        if (item.note.trim().isNotEmpty) ...[const SizedBox(height: 18), NoteBox(item)],
      ],
    );
  }
}

/// The short note, folded when it is long.
class NoteBox extends StatefulWidget {
  const NoteBox(this.item, {super.key});

  final ContentItem item;

  @override
  State<NoteBox> createState() => _NoteBoxState();
}

class _NoteBoxState extends State<NoteBox> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final note = widget.item.note.trim();
    final long = note.length > 260;
    final label = widget.item.isAyah ? 'টীকা · আবু বকর যাকারিয়া' : 'সংক্ষিপ্ত ব্যাখ্যা';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(color: p.surfaceSoft, borderRadius: BorderRadius.circular(radiusM)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: BanglaText(note, size: 15, maxLines: long && !_open ? 5 : null),
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'কম দেখুন' : 'পুরোটা পড়ুন'),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
