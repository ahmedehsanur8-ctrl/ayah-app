import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/reminders.dart';
import '../services/rotation.dart';
import '../theme.dart';
import '../widgets/item_view.dart';
import 'credits_screen.dart';
import 'reading_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _ayahOffset = 0;
  int _hadithOffset = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final now = Reminders.nowDhaka();
    final today = Rotation.dayNumber(now);
    final ayah = state.rotation.morning(today + _ayahOffset);
    final hadith = state.rotation.hadithFor(today + _hadithOffset);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayah Reminder'),
        actions: [
          IconButton(
            tooltip: 'কৃতজ্ঞতা',
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CreditsScreen())),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) {
          final marks = state.settings.readMarks;
          final todayKey = dateKey(now);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Greeting(hour: now.hour),
              const SizedBox(height: 16),
              if (ayah != null)
                _DailyCard(
                  heading: _ayahOffset == 0 ? 'আজকের আয়াত' : 'আয়াত',
                  icon: Icons.wb_sunny_outlined,
                  item: ayah,
                  read: _ayahOffset == 0 && marks.contains('$todayKey-morning'),
                  onPrev: () => setState(() => _ayahOffset--),
                  onNext: () => setState(() => _ayahOffset++),
                  onToday: _ayahOffset == 0 ? null : () => setState(() => _ayahOffset = 0),
                ),
              const SizedBox(height: 16),
              if (hadith != null)
                _DailyCard(
                  heading: _hadithOffset == 0 ? 'আজকের হাদিস' : 'হাদিস',
                  icon: Icons.nightlight_outlined,
                  item: hadith,
                  read: _hadithOffset == 0 && marks.contains('$todayKey-night'),
                  onPrev: () => setState(() => _hadithOffset--),
                  onNext: () => setState(() => _hadithOffset++),
                  onToday: _hadithOffset == 0 ? null : () => setState(() => _hadithOffset = 0),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    final text = hour < 12
        ? 'শুভ সকাল! আজকের দিনটি শুরু হোক আল্লাহর বাণী দিয়ে।'
        : hour < 18
        ? 'আসসালামু আলাইকুম! একটু থেমে পড়ে নিন।'
        : 'শুভ রাত্রি! দিনের শেষে একটি হাদিস পড়ে নিন।';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.deepGreen, AppColors.green]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.mosque_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.heading,
    required this.icon,
    required this.item,
    required this.read,
    required this.onPrev,
    required this.onNext,
    this.onToday,
  });

  final String heading;
  final IconData icon;
  final ContentItem item;
  final bool read;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ReadingScreen(item: item))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                  if (read)
                    const Chip(
                      avatar: Icon(Icons.check, size: 16, color: AppColors.green),
                      label: Text('পড়া হয়েছে'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: CategoryChip(item)),
              const SizedBox(height: 12),
              ArabicText(item.arabic, size: item.isAyah ? 24 : 20, maxLines: 6),
              const OrnamentDivider(),
              BanglaText(item.bangla, size: 16, maxLines: 7),
              const SizedBox(height: 8),
              BanglaText(item.title, size: 13.5, color: AppColors.green),
              const SizedBox(height: 4),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onPrev,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('আগের'),
                  ),
                  const Spacer(),
                  if (onToday != null)
                    TextButton(onPressed: onToday, child: const Text('আজ'))
                  else
                    const Text(
                      'পুরোটা পড়তে ছুঁয়ে দিন',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onNext,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('পরের'), Icon(Icons.chevron_right)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
