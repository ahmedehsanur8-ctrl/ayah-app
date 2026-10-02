import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/fasting.dart';
import '../services/prayer.dart';
import '../theme.dart';
import '../utils/bangla.dart';
import '../widgets/night.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart' show pickOption;

String _clock(DateTime t) => formatClock(t);

/// Home (inside the night header): "সেহরির শেষ সময়" and "ইফতার" for the next fast.
class HomeSehriIftar extends StatelessWidget {
  const HomeSehriIftar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance.settings;
    final now = DateTime.now();
    if (!Fasting.showOnHome(s, now)) return const SizedBox.shrink();
    final day = Fasting.nextFastDate(s, now);
    final f = Fasting.forDay(s, day);
    if (f == null) return const SizedBox.shrink();
    final tomorrow = Fasting.naflIsTomorrow(s, now);
    final p = context.palette;
    Widget box(IconData icon, String label, DateTime t) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(color: p.nightLine, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: p.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label, style: TextStyle(color: p.onNightMuted, fontSize: 14)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _clock(t),
                      style: TextStyle(color: p.gold, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        container: true,
        label:
            '${tomorrow ? 'আগামীকাল ' : ''}সেহরির শেষ সময় ${_clock(f.sehriEnd)}, ইফতার ${_clock(f.iftar)}',
        excludeSemantics: true,
        child: Row(
          children: [
            box(
              Icons.dark_mode_outlined,
              tomorrow ? 'কাল সেহরির শেষ সময়' : 'সেহরির শেষ সময়',
              f.sehriEnd,
            ),
            const SizedBox(width: 8),
            box(Icons.wb_twilight_outlined, tomorrow ? 'কাল ইফতার' : 'ইফতার', f.iftar),
          ],
        ),
      ),
    );
  }
}

/// Prayer times page: today's sehri and iftar, and in Ramadan the timetable.
class SehriIftarCard extends StatelessWidget {
  const SehriIftarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    final now = DateTime.now();
    final today = Fasting.forDay(s, now);
    if (today == null) return const SizedBox.shrink();
    final table = Fasting.ramadanTimetable(s, now);
    final todayKey = DateUtils.dateOnly(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('সেহরি ও ইফতার'),
        ListSection(
          children: [
            ListRow(
              icon: Icons.dark_mode_outlined,
              title: 'আজ সেহরির শেষ সময়',
              subtitle: Fasting.precautionText(s.sehriPrecaution),
              trailing: Text(
                _clock(today.sehriEnd),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
              ),
            ),
            ListRow(
              icon: Icons.wb_twilight_outlined,
              title: 'আজ ইফতার',
              subtitle: 'মাগরিবের সময়',
              trailing: Text(
                _clock(today.iftar),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
              ),
            ),
          ],
        ),
        if (table.isNotEmpty) ...[
          const SectionLabel('রমজানের সময়সূচি'),
          ListSection(
            indent: 0,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: _head(p, 'তারিখ')),
                    Expanded(flex: 4, child: _head(p, 'সেহরি শেষ')),
                    Expanded(flex: 4, child: _head(p, 'ইফতার')),
                  ],
                ),
              ),
              for (final d in table)
                Container(
                  color: d.date == todayKey ? p.pill : null,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          '${toBanglaDigits(d.hijriDay)} রমজান\n${banglaDate(d.date).split(', ').last}',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: p.text,
                            fontWeight: d.date == todayKey ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(flex: 4, child: _cell(p, formatClock(d.sehriEnd, withPart: false))),
                      Expanded(flex: 4, child: _cell(p, formatClock(d.iftar, withPart: false))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'রমজান হিজরি হিসাব থেকে; স্থানীয় চাঁদ দেখার সাথে মেলাতে সেটিংস → সেহরি ও ইফতার → '
            '"হিজরি তারিখ সমন্বয়" বদলান।',
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
          ),
        ],
      ],
    );
  }

  static Widget _head(Palette p, String t) => Text(
    t,
    style: TextStyle(color: p.muted, fontSize: 14, fontWeight: FontWeight.w600),
  );

  static Widget _cell(Palette p, String t) => Text(
    t,
    style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w600),
  );
}

/// Settings → সেহরি ও ইফতার.
class SehriIftarSettings extends StatelessWidget {
  const SehriIftarSettings({super.key});

  String _minutes(int m, String after) => m == 0 ? 'বন্ধ' : '${toBanglaDigits(m)} মিনিট $after';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final now = DateTime.now();
        final f = Fasting.forDay(s, Fasting.nextFastDate(s, now));
        final tomorrow = Fasting.naflIsTomorrow(s, now);
        final h = Fasting.hijriText(s, now);
        Future<void> changed() => Prayers.schedule(s);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RowGroup(
              children: [
                NavRow(
                  icon: Icons.timer_outlined,
                  title: 'সেহরির সতর্কতা',
                  subtitle: [
                    Fasting.precautionText(s.sehriPrecaution),
                    if (f != null) 'সেহরি শেষ ${formatClock(f.sehriEnd)}',
                  ].join(', '),
                  onTap: () async {
                    final v = await pickOption<int>(
                      context,
                      'সেহরি কত আগে শেষ',
                      s.sehriPrecaution,
                      {
                        for (final m in Fasting.precautions)
                          m: m == 0
                              ? '০ মিনিট (ফজর শুরুর সময়েই)'
                              : '${toBanglaDigits(m)} মিনিট আগে',
                      },
                    );
                    if (v != null) {
                      await s.setSehriPrecaution(v);
                      await changed();
                    }
                  },
                ),
                NavRow(
                  icon: Icons.home_outlined,
                  title: 'হোমে দেখান',
                  subtitle: Fasting.showModes[s.sehriShowMode],
                  onTap: () async {
                    final v = await pickOption<String>(
                      context,
                      'হোমে সেহরি ও ইফতার',
                      s.sehriShowMode,
                      Fasting.showModes,
                    );
                    if (v != null) await s.setSehriShowMode(v);
                  },
                ),
                NavRow(
                  icon: Icons.volunteer_activism_outlined,
                  title: tomorrow ? 'কাল রোজা রাখছি' : 'আজ রোজা রাখছি',
                  subtitle:
                      'নফল রোজার জন্য: হোমে সময় দেখাবে, অ্যালার্ম ও ইফতার রিমাইন্ডার চালু থাকবে',
                  trailing: Switch(
                    value: Fasting.naflOn(s, now),
                    onChanged: (v) async {
                      await Fasting.setNafl(s, now, v);
                      await changed();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RowGroup(
              children: [
                NavRow(
                  icon: Icons.alarm_outlined,
                  title: 'সেহরির অ্যালার্ম',
                  subtitle: s.sehriAlarm == 0
                      ? 'বন্ধ'
                      : 'সেহরি শেষ হওয়ার ${toBanglaDigits(s.sehriAlarm)} মিনিট আগে, অ্যালার্মের মতো শব্দসহ',
                  onTap: () async {
                    final v = await pickOption<int>(context, 'সেহরির অ্যালার্ম', s.sehriAlarm, {
                      for (final m in Fasting.alarmOptions) m: _minutes(m, 'আগে'),
                    });
                    if (v != null) {
                      await s.setSehriAlarm(v);
                      await changed();
                    }
                  },
                ),
                NavRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'ইফতারের রিমাইন্ডার',
                  subtitle: _minutes(s.iftarBefore, 'আগে'),
                  onTap: () async {
                    final v = await pickOption<int>(context, 'ইফতারের রিমাইন্ডার', s.iftarBefore, {
                      for (final m in Fasting.iftarOptions) m: _minutes(m, 'আগে'),
                    });
                    if (v != null) {
                      await s.setIftarBefore(v);
                      await changed();
                    }
                  },
                ),
                NavRow(
                  icon: Icons.front_hand_outlined,
                  title: 'ইফতারের সময় দোয়াসহ নোটিফিকেশন',
                  subtitle: '"যাহাবায যামা’উ…" (সুনান আবু দাউদ ২৩৫৭)',
                  trailing: Switch(
                    value: s.iftarNotify,
                    onChanged: (v) async {
                      await s.setIftarNotify(v);
                      await changed();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RowGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'হিজরি তারিখ সমন্বয়',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                      ),
                      Text(
                        'আজ: $h${s.hijriOffset == 0 ? '' : ' (${_signed(s.hijriOffset)} দিন)'}',
                        style: TextStyle(fontSize: 14, color: p.muted),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          for (final d in const [-2, -1, 0, 1, 2])
                            ButtonSegment(value: d, label: Text(_signed(d))),
                        ],
                        selected: {s.hijriOffset},
                        onSelectionChanged: (v) async {
                          await s.setHijriOffset(v.first);
                          await changed();
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'হিজরি তারিখ হিসাব করে বের করা হয়। বাংলাদেশে চাঁদ দেখার কারণে ১–২ দিন '
                        'পার্থক্য হতে পারে; রমজান কবে শুরু তা এখান থেকে মিলিয়ে নিন।',
                        style: TextStyle(fontSize: 14, color: p.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'অ্যালার্ম ও রিমাইন্ডার রমজানে এবং "রোজা রাখছি" চালু করা দিনে বাজবে। '
              'সেহরি = ফজর শুরু (সুবহে সাদিক) থেকে সতর্কতার মিনিট বাদ দিয়ে; ইফতার = মাগরিব।',
              style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
            ),
          ],
        );
      },
    );
  }

  static String _signed(int d) => d == 0 ? '০' : '${d > 0 ? '+' : '−'}${toBanglaDigits(d.abs())}';
}
