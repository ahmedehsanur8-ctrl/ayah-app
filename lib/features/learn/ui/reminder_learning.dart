import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../models/content.dart';
import '../../../theme.dart';
import '../../../widgets/item_view.dart';
import '../../../widgets/ui.dart';
import '../domain/models.dart';
import '../state/learn_controller.dart';
import 'screens/learn_screens.dart';
import 'widgets/learn_widgets.dart';

/// The one button on the reminder screen, under the Bangla meaning: opens the
/// reminder's ayah with tappable words.
class UnderstandAyahButton extends StatelessWidget {
  const UnderstandAyahButton({super.key, required this.item});

  final ContentItem item;

  /// Only for ayahs.
  static Widget? forItem(ContentItem item) =>
      item.isAyah && item.surah > 0 && item.ayahStart > 0 ? UnderstandAyahButton(item: item) : null;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => push(
        context,
        LearnAyahScreen(
          surah: item.surah,
          ayah: item.ayahStart,
          to: item.ayahEnd >= item.ayahStart ? item.ayahEnd : item.ayahStart,
        ),
      ),
      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      icon: const Icon(Icons.translate_rounded),
      label: const Text('এই আয়াত বুঝুন', style: TextStyle(fontSize: 16)),
    ),
  );
}

/// Learning mode on the reminder screen: the same ayah, but as Tanzil words with
/// the known ones tinted and underlined, and "৯টি শব্দের ৪টি চেনেন" under it.
/// Off (default) or for hadiths, the reminder shows its usual Arabic.
class ReminderLearningAyah extends StatefulWidget {
  const ReminderLearningAyah({super.key, required this.item});

  final ContentItem item;

  static Widget? forItem(ContentItem item) =>
      AppState.instance.settings.learnModeOn && UnderstandAyahButton.forItem(item) != null
      ? ReminderLearningAyah(item: item)
      : null;

  @override
  State<ReminderLearningAyah> createState() => _ReminderLearningAyahState();
}

class _ReminderLearningAyahState extends State<ReminderLearningAyah> {
  List<QuranWord>? _words;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final learn = Learn.instance;
      await learn.ensureReady();
      final i = widget.item;
      final w = await learn.content!.ayahWords(
        i.surah,
        i.ayahStart,
        i.ayahEnd >= i.ayahStart ? i.ayahEnd : i.ayahStart,
      );
      if (mounted && w.isNotEmpty) setState(() => _words = w);
    } catch (_) {
      // Keep the usual Arabic if the word list cannot be opened.
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final item = widget.item;
    // Until the words are ready (and if they never are), the usual Arabic.
    if (words == null) return ArabicText(item.arabic, size: 31);
    final learn = Learn.instance;
    final counted = words.where((w) => w.lemmaId != null).toList();
    final known = counted.where(learn.isKnown).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TappableAyah(words: words, isKnown: learn.isKnown, size: 30),
        Text(
          knownLine(known, counted.length),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: context.palette.primary),
        ),
      ],
    );
  }
}
