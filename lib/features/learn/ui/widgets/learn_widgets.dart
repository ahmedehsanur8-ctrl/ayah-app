import 'package:flutter/material.dart';

import '../../../../app_state.dart';
import '../../../../models/content.dart';
import '../../../../theme.dart';
import '../../domain/models.dart';
import '../../srs/srs_service.dart';

/// Arabic always sits in its own RTL widget, in the app's Quran font, at least 26.
/// [highlight] colours one part of the word (a prefix or pronoun), [known] adds
/// the known-word tint and underline (colour is never the only signal).
class ArabicWord extends StatelessWidget {
  const ArabicWord(
    this.word, {
    super.key,
    this.size = 30,
    this.highlight,
    this.known = false,
    this.color,
  });

  final QuranWord word;
  final double size;
  final (int, int)? highlight;
  final bool known;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scale = AppState.instance.settings.textScale;
    final base = TextStyle(
      fontFamily: arabicFont,
      fontSize: size * scale,
      height: 1.9,
      color: color ?? p.arabic,
      decoration: known ? TextDecoration.underline : null,
      decorationColor: p.primary,
      decorationThickness: 2,
    );
    final t = word.text;
    final h = highlight;
    final span = h == null || (h.$1 == 0 && h.$2 == t.length)
        ? TextSpan(text: t, style: base)
        : TextSpan(
            style: base,
            children: [
              TextSpan(text: t.substring(0, h.$1)),
              TextSpan(
                text: t.substring(h.$1, h.$2),
                style: TextStyle(color: p.primary, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: t.substring(h.$2)),
            ],
          );
    // Amiri Quran draws marks far above and below the line: keep room so the
    // word never runs into the Bangla text next to it.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size * scale * 0.3),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text.rich(span, textAlign: TextAlign.center),
      ),
    );
  }
}

/// "খসড়া": shown on every meaning or lesson a teacher has not reviewed yet.
class DraftBadge extends StatelessWidget {
  const DraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.palette.sand;
    return Semantics(
      label: 'খসড়া, শিক্ষক এখনো যাচাই করেননি',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(20)),
        child: Text(
          'খসড়া',
          style: TextStyle(fontSize: 14, color: t.foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// An ayah as tappable words, right to left. Known words get a tint and an
/// underline. Tapping a word calls [onTap].
class TappableAyah extends StatelessWidget {
  const TappableAyah({
    super.key,
    required this.words,
    required this.isKnown,
    this.onTap,
    this.size = 28,
  });

  final List<QuranWord> words;
  final bool Function(QuranWord) isKnown;
  final void Function(QuranWord)? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final w in words)
            Semantics(
              button: onTap != null,
              label: isKnown(w) ? 'চেনা শব্দ' : 'শব্দ',
              child: Material(
                color: isKnown(w) ? p.mint.background : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap == null ? null : () => onTap!(w),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ArabicWord(w, size: size, known: isKnown(w)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "৯টি শব্দের ৪টি চেনেন"
String knownLine(int known, int total) =>
    '${toBanglaDigits(total)}টি শব্দের ${toBanglaDigits(known)}টি চেনেন';

/// The four self-rating buttons, full width on small phones.
class RatingBar extends StatelessWidget {
  const RatingBar({super.key, required this.onRate, this.allowEasy = true});

  final void Function(Rating) onRate;
  final bool allowEasy;

  static const labels = {
    Rating.again: 'ভুলে গেছি',
    Rating.hard: 'কষ্টে',
    Rating.good: 'মনে আছে',
    Rating.easy: 'সহজ',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tints = {
      Rating.again: p.rose,
      Rating.hard: p.sand,
      Rating.good: p.mint,
      Rating.easy: p.sky,
    };
    final ratings = [Rating.again, Rating.hard, Rating.good, if (allowEasy) Rating.easy];
    Widget b(Rating r) => FilledButton(
      onPressed: () => onRate(r),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: tints[r]!.background,
        foregroundColor: tints[r]!.foreground,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(labels[r]!),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 420
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: b(ratings[0])),
                    const SizedBox(width: 8),
                    Expanded(child: b(ratings[1])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: b(ratings[2])),
                    if (ratings.length > 3) ...[
                      const SizedBox(width: 8),
                      Expanded(child: b(ratings[3])),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < ratings.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: b(ratings[i])),
                ],
              ],
            ),
    );
  }
}

/// Bangla body text in lessons: at least 16, line height 1.5.
class LessonText extends StatelessWidget {
  const LessonText(this.text, {super.key, this.size = 17, this.color, this.weight, this.align});

  final String text;
  final double size;
  final Color? color;
  final FontWeight? weight;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      height: 1.5,
      color: color ?? context.palette.text,
      fontWeight: weight,
    ),
  );
}
