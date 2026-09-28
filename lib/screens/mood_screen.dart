import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';
import '../widgets/category_style.dart';
import '../widgets/ui.dart';
import 'collection_screen.dart';

/// মন: "তোমার মন এখন কেমন?" with the 16 moods in a 3-column grid.
class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});

  static void open(BuildContext context, Mood m) {
    final data = AppState.instance.data;
    push(
      context,
      CollectionScreen(
        styleId: m.id,
        title: m.name,
        ayahs: data.byIds(m.ayahIds),
        surahs: data.byIds(m.surahIds),
        hadiths: data.byIds(m.hadithIds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final moods = AppState.instance.data.moods;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(
                child: PageTitle(
                  'তোমার মন এখন কেমন?',
                  subtitle: 'যেমন লাগছে সেটি বেছে নাও — তার জন্য কুরআনের আয়াত ও হাদিস।',
                ),
              ),
            ),
            if (moods.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('মনের অবস্থার তালিকা শীঘ্রই আসছে।', style: TextStyle(color: p.muted)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.98,
                  ),
                  itemCount: moods.length,
                  itemBuilder: (context, i) {
                    final m = moods[i];
                    final style = CategoryStyle.of(m.id);
                    return GridTile3(
                      icon: style.icon,
                      tint: style.tintOf(p),
                      title: m.name,
                      onTap: () => open(context, m),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
