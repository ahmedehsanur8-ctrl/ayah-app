import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';
import '../widgets/category_style.dart';
import '../widgets/night.dart';
import '../widgets/ui.dart';
import 'collection_screen.dart';
import 'topics_screen.dart';

/// মন tab: "আপনার মন এখন কেমন?" with the 16 moods, then all the topics (বিষয়).
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
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const NightHeader(
              title: 'আপনার মন এখন কেমন?',
              subtitle: 'যেমন লাগছে সেটি বেছে নিন — তার জন্য কুরআনের আয়াত ও হাদিস।',
              lip: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (moods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'মনের অবস্থার তালিকা শীঘ্রই আসছে।',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.muted),
                      ),
                    )
                  else
                    ListSection(
                      children: [
                        for (final m in moods)
                          ListRow(
                            icon: CategoryStyle.of(m.id).icon,
                            title: m.name,
                            onTap: () => open(context, m),
                          ),
                      ],
                    ),
                  const SectionLabel('বিষয় অনুযায়ী আয়াত ও হাদিস'),
                  const TopicsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
