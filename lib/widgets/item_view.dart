import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';

/// Arabic text, right-to-left, in the Amiri Quran font.
class ArabicText extends StatelessWidget {
  const ArabicText(this.text, {super.key, this.size = 26, this.maxLines});

  final String text;
  final double size;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
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
            height: 2.0,
            color: AppColors.deepGreen,
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
  });

  final String text;
  final double size;
  final int? maxLines;
  final Color? color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final settings = AppState.instance.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: banglaFont,
          fontSize: size * settings.textScale,
          height: 1.65,
          color: color ?? AppColors.text,
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip(this.item, {super.key});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.isAyah ? Icons.menu_book_rounded : Icons.format_quote_rounded,
            size: 15,
            color: AppColors.green,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${item.isAyah ? 'আয়াত' : 'হাদিস'} · ${item.category}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative divider with a small star.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFDCEBE1))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
          ),
          Expanded(child: Divider(color: Color(0xFFDCEBE1))),
        ],
      ),
    );
  }
}

/// The full text of an item: Arabic, Bangla, reference and note.
class ItemBody extends StatelessWidget {
  const ItemBody(this.item, {super.key});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: CategoryChip(item)),
        const SizedBox(height: 16),
        ArabicText(item.arabic, size: item.isAyah ? 28 : 23),
        const OrnamentDivider(),
        BanglaText(item.bangla, size: 18),
        const SizedBox(height: 14),
        BanglaText(item.title, size: 14.5, color: AppColors.green),
        if (item.subtitle.isNotEmpty) BanglaText(item.subtitle, size: 13, color: AppColors.muted),
        if (item.placeholder)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: BanglaText('কিছু লেখা ডাউনলোড করা যায়নি।', size: 13, color: Colors.red),
          ),
        if (item.note.trim().isNotEmpty) ...[const SizedBox(height: 12), NoteBox(item)],
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
    final note = widget.item.note.trim();
    final long = note.length > 260;
    final label = widget.item.isAyah
        ? 'টীকা (আবু বকর যাকারিয়া)'
        : 'সংক্ষিপ্ত ব্যাখ্যা (HadeethEnc)';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BanglaText(note, size: 15, maxLines: long && !_open ? 5 : null),
          if (long)
            TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'কম দেখুন' : 'পুরোটা পড়ুন'),
            ),
        ],
      ),
    );
  }
}
