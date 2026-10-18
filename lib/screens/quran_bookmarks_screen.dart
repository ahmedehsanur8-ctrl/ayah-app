import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/quran.dart';
import '../theme.dart';
import '../widgets/quran_widgets.dart';
import '../widgets/ui.dart';
import 'quran_reader_screen.dart';

/// The bookmarked ayahs in a card (the বুকমার্ক tab of the প্রিয় page).
class QuranBookmarkList extends StatelessWidget {
  const QuranBookmarkList({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prefs = AppState.instance.settings.quran;
    return FutureBuilder(
      future: Quran.load(),
      builder: (context, _) => ListenableBuilder(
        listenable: prefs,
        builder: (context, _) {
          final refs = prefs.bookmarks
              .map(AyahRef.parse)
              .nonNulls
              .where((r) => Quran.isValid(r.surah, r.ayah))
              .toList();
          final t = Quran.loaded['bn_zakaria'];
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < refs.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  InkWell(
                    onTap: () =>
                        push(context, QuranReaderScreen(surah: refs[i].surah, ayah: refs[i].ayah)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ayahTitle(refs[i].surah, refs[i].ayah),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: p.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (t != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    t.text[Quran.indexOf(refs[i].surah, refs[i].ayah)],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14, color: p.text, height: 1.5),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'বুকমার্ক সরান',
                            onPressed: () => prefs.toggleBookmark(refs[i].surah, refs[i].ayah),
                            icon: Icon(Icons.bookmark_rounded, color: p.goldText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
