import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../theme.dart';
import '../widgets/item_view.dart';
import '../widgets/ui.dart';

/// One zikr for the tasbih: Arabic, Bangla pronunciation and meaning.
class TasbihZikr {
  const TasbihZikr(this.arabic, this.bangla, this.meaning);

  final String arabic;
  final String bangla;
  final String meaning;

  static const all = [
    TasbihZikr('سُبْحَانَ اللَّهِ', 'সুবহানাল্লাহ', 'আল্লাহ পবিত্র'),
    TasbihZikr('الْحَمْدُ لِلَّهِ', 'আলহামদুলিল্লাহ', 'সব প্রশংসা আল্লাহর'),
    TasbihZikr('اللَّهُ أَكْبَرُ', 'আল্লাহু আকবার', 'আল্লাহ সবচেয়ে বড়'),
    TasbihZikr('لَا إِلَٰهَ إِلَّا اللَّهُ', 'লা ইলাহা ইল্লাল্লাহ', 'আল্লাহ ছাড়া কোনো উপাস্য নেই'),
    TasbihZikr('أَسْتَغْفِرُ اللَّهَ', 'আস্তাগফিরুল্লাহ', 'আমি আল্লাহর কাছে ক্ষমা চাই'),
    TasbihZikr('', 'শুধু গণনা', 'যেকোনো জিকির গুনে রাখুন'),
  ];
}

/// তাসবিহ: a big tap area that counts, with a chosen zikr and target.
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  static const targets = [33, 99, 100, 0];

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  final _s = AppState.instance.settings;
  late int _count = _s.tasbihCount;
  late int _zikr = _s.tasbihZikr.clamp(0, TasbihZikr.all.length - 1);
  late int _target = TasbihScreen.targets.contains(_s.tasbihTarget) ? _s.tasbihTarget : 33;

  void _save() => _s.saveTasbih(count: _count, zikr: _zikr, target: _target);

  void _tap() {
    setState(() => _count++);
    if (_target > 0 && _count % _target == 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('মাশাআল্লাহ! ${toBanglaDigits(_target)} বার পূর্ণ হয়েছে।'),
          ),
        );
    } else {
      HapticFeedback.selectionClick();
    }
    _save();
  }

  void _reset() {
    setState(() => _count = 0);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final z = TasbihZikr.all[_zikr];
    final inRound = _target == 0 ? _count : _count % _target;
    final rounds = _target == 0 ? 0 : _count ~/ _target;
    return Scaffold(
      appBar: AppBar(
        title: const Text('তাসবিহ'),
        actions: [
          TextButton.icon(
            onPressed: _count == 0 ? null : _reset,
            style: TextButton.styleFrom(
              foregroundColor: p.gold,
              disabledForegroundColor: p.onNight.withValues(alpha: 0.5),
            ),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('আবার শুরু'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: TasbihZikr.all.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ChoiceChip(
                    label: Text(TasbihZikr.all[i].bangla),
                    selected: i == _zikr,
                    onSelected: (_) {
                      setState(() {
                        _zikr = i;
                        _count = 0;
                      });
                      _save();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('লক্ষ্য', style: TextStyle(color: p.muted, fontSize: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: [
                        for (final t in TasbihScreen.targets)
                          ButtonSegment(value: t, label: Text(t == 0 ? 'নেই' : toBanglaDigits(t))),
                      ],
                      selected: {_target},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) {
                        setState(() => _target = v.first);
                        _save();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    if (z.arabic.isNotEmpty) ArabicText(z.arabic, size: 30),
                    Text(
                      z.bangla,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.primary),
                    ),
                    Text(
                      z.meaning,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final size = ((c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) - 8).clamp(
                      160.0,
                      320.0,
                    );
                    // Night circle with a gold ring that fills toward the target.
                    return Center(
                      child: Semantics(
                        button: true,
                        label: 'গণনা করতে চাপ দিন',
                        value: toBanglaDigits(_count),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.square(
                              dimension: size,
                              child: CircularProgressIndicator(
                                value: _target == 0 ? 0 : inRound / _target,
                                strokeWidth: 7,
                                color: p.gold,
                                backgroundColor: p.border,
                                semanticsLabel: 'লক্ষ্যের অগ্রগতি',
                              ),
                            ),
                            Material(
                              color: p.night,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: const ValueKey('tasbih-tap'),
                                onTap: _tap,
                                child: SizedBox.square(
                                  dimension: size - 20,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FittedBox(
                                        child: Text(
                                          toBanglaDigits(inRound),
                                          style: TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.w700,
                                            color: p.onNight,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _target == 0 ? 'চাপ দিন' : '/ ${toBanglaDigits(_target)}',
                                        style: TextStyle(color: p.gold, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _target == 0
                    ? 'মোট ${toBanglaDigits(_count)} বার'
                    : 'মোট ${toBanglaDigits(_count)} বার, ${toBanglaDigits(rounds)} রাউন্ড পূর্ণ',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card that opens the tasbih (দোয়া tab).
class TasbihCard extends StatelessWidget {
  const TasbihCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return RowGroup(
      children: [
        NavRow(
          icon: Icons.touch_app_outlined,
          tint: p.sand,
          title: 'তাসবিহ',
          subtitle: 'সুবহানাল্লাহ, আলহামদুলিল্লাহ… চাপ দিয়ে গুনুন',
          onTap: () => push(context, const TasbihScreen()),
        ),
      ],
    );
  }
}
