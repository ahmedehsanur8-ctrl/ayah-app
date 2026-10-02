import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/compass.dart';
import '../services/prayer.dart';
import '../theme.dart';
import '../widgets/night.dart';
import 'prayer_screen.dart';

/// কিবলা: compass with the Kaaba at the arrow tip. Works offline.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassReading>? _sub;
  CompassReading? _reading;
  bool _noCompass = false;
  bool _wasFacing = false;
  String _listeningFor = '';

  static const facingWithin = 5.0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final s = AppState.instance.settings;
    final key = '${s.latitude},${s.longitude}';
    if (key == _listeningFor) return;
    _listeningFor = key;
    _sub?.cancel();
    _sub = Compass.readings(lat: s.latitude, lng: s.longitude).listen(
      (r) {
        if (!mounted) return;
        setState(() => _reading = r);
        final q = Prayers.qibla(s);
        if (q == null) return;
        final facing = _diff(q, r.heading).abs() <= facingWithin;
        if (facing && !_wasFacing) HapticFeedback.mediumImpact();
        _wasFacing = facing;
      },
      onError: (_) {
        if (mounted) setState(() => _noCompass = true);
      },
    );
  }

  /// Signed angle from [heading] to [target], -180..180 (positive = turn right).
  static double _diff(double target, double heading) => ((target - heading + 540) % 360) - 180;

  static String directionName(double deg) {
    const names = [
      'উত্তর',
      'উত্তর-পূর্ব',
      'পূর্ব',
      'দক্ষিণ-পূর্ব',
      'দক্ষিণ',
      'দক্ষিণ-পশ্চিম',
      'পশ্চিম',
      'উত্তর-পশ্চিম',
    ];
    return names[((deg % 360) / 45).round() % 8];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance.settings;
    final p = context.palette;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (!s.hasLocation) {
          return Scaffold(
            appBar: AppBar(title: const Text('কিবলা')),
            body: const ChooseLocationView(),
          );
        }
        _listen();
        // Full night screen with the girih pattern.
        return Scaffold(
          backgroundColor: p.night,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Stack(
              children: [
                const GirihLayer(),
                SafeArea(child: _compass(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _compass(BuildContext context) {
    final p = context.palette;
    final s = AppState.instance.settings;
    final q = Prayers.qibla(s)!;
    final heading = _reading?.heading;
    final diff = heading == null ? null : _diff(q, heading);
    final facing = diff != null && diff.abs() <= facingWithin;
    final qDeg = toBanglaDigits(q.round());

    String hint;
    if (_noCompass) {
      hint = 'এই ফোনে কম্পাস নেই। উত্তর দিক থেকে ঘড়ির কাঁটার দিকে $qDeg° ঘুরলে কিবলা।';
    } else if (diff == null) {
      hint = 'কম্পাস চালু হচ্ছে…';
    } else if (facing) {
      hint = 'আপনি কিবলামুখী আছেন';
    } else {
      final turn = toBanglaDigits(diff.abs().round());
      hint = diff > 0 ? 'ডানে $turn° ঘুরুন' : 'বামে $turn° ঘুরুন';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop()) const NightBackButton(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Semantics(
                  header: true,
                  child: Text('কিবলা', style: nightTitleStyle(p, size: 24)),
                ),
              ),
            ),
            Flexible(
              child: NightPill(
                icon: Icons.location_on_outlined,
                text: s.placeName.isEmpty ? 'অবস্থান' : s.placeName,
                onTap: () => showLocationSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) => CustomPaint(
              painter: _CompassPainter(palette: p, heading: heading ?? 0, qibla: q, facing: facing),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Emerald pill when facing the Qibla; otherwise the turn hint.
        Center(
          child: Semantics(
            liveRegion: true,
            child: AnimatedContainer(
              duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: facing ? p.action : p.nightLine,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    facing ? Icons.check_circle_outline_rounded : Icons.explore_outlined,
                    color: facing ? p.onPrimary : p.gold,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: facing ? p.onPrimary : p.onNight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.nightLine,
            borderRadius: BorderRadius.circular(radiusM),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('কিবলার দিক', style: TextStyle(color: p.onNightMuted, fontSize: 14)),
                    Text(
                      '$qDeg° · ${directionName(q)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.gold),
                    ),
                  ],
                ),
              ),
              if (heading != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ফোনের দিক', style: TextStyle(color: p.onNightMuted, fontSize: 14)),
                    Text(
                      '${toBanglaDigits(heading.round())}° · ${directionName(heading)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.onNight),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.nightLine,
            borderRadius: BorderRadius.circular(radiusM),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.all_inclusive_rounded, color: p.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (_reading?.needsCalibration ?? false)
                      ? 'কম্পাস ঠিক করতে হবে: ফোনটি বাতাসে ইংরেজি ৮ অক্ষরের মতো করে কয়েকবার ঘোরান।'
                      : 'দিক ঠিক না মনে হলে ফোনটি বাতাসে ইংরেজি ৮ অক্ষরের মতো করে কয়েকবার ঘোরান। '
                            'ফোন সমতলে রাখুন, চুম্বক বা লোহার জিনিস থেকে দূরে থাকুন।',
                  style: TextStyle(
                    color: p.onNight,
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: (_reading?.needsCalibration ?? false)
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.palette,
    required this.heading,
    required this.qibla,
    required this.facing,
  });

  final Palette palette;
  final double heading;
  final double qibla;
  final bool facing;

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;

    // Dial: a gold ring on the night background (emerald when facing).
    canvas.drawCircle(c, r, Paint()..color = p.nightDeep.withValues(alpha: 0.7));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = facing ? p.primary : p.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = facing ? 5 : 3,
    );
    canvas.drawCircle(
      c,
      r - 22,
      Paint()
        ..color = p.gold.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    // Rotate so the dial's north points to real north.
    canvas.rotate(_rad(-heading));

    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0;
      final inner = r - (major ? 16 : 9);
      final a = _rad(d.toDouble());
      canvas.drawLine(
        Offset(math.sin(a) * inner, -math.cos(a) * inner),
        Offset(math.sin(a) * (r - 4), -math.cos(a) * (r - 4)),
        Paint()
          ..color = major ? p.gold : p.onNight.withValues(alpha: 0.3)
          ..strokeWidth = major ? 2 : 1,
      );
    }

    const labels = {0: 'উ', 90: 'পূ', 180: 'দ', 270: 'প'};
    for (final e in labels.entries) {
      final a = _rad(e.key.toDouble());
      final pos = Offset(math.sin(a) * (r - 34), -math.cos(a) * (r - 34));
      final tp = TextPainter(
        text: TextSpan(
          text: e.value,
          style: TextStyle(
            fontFamily: banglaFont,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: e.key == 0 ? p.northOnNight : p.onNight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(_rad(heading)); // keep letters upright
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Qibla arrow with the Kaaba at its tip.
    canvas.rotate(_rad(qibla));
    final arrowColor = facing ? p.primary : p.gold;
    // The Kaaba sits inside the letter ring, so it never covers উ/পূ/দ/প.
    final tipY = -(r - 96);
    final path = Path()
      ..moveTo(0, tipY)
      ..lineTo(12, tipY + 26)
      ..lineTo(4, tipY + 22)
      ..lineTo(4, 22)
      ..lineTo(-4, 22)
      ..lineTo(-4, tipY + 22)
      ..lineTo(-12, tipY + 26)
      ..close();
    canvas.drawPath(path, Paint()..color = arrowColor);
    _kaaba(canvas, Offset(0, tipY - 24), 34);
    canvas.restore();

    // Centre dot and a fixed marker at the top: where the phone points.
    canvas.drawCircle(c, 8, Paint()..color = p.gold);
    final top = Path()
      ..moveTo(c.dx, c.dy - r - 4)
      ..lineTo(c.dx - 9, c.dy - r + 12)
      ..lineTo(c.dx + 9, c.dy - r + 12)
      ..close();
    canvas.drawPath(top, Paint()..color = p.onNight);
  }

  /// A small Kaaba: black cube with a gold band and door.
  void _kaaba(Canvas canvas, Offset centre, double s) {
    final rect = Rect.fromCenter(center: centre, width: s, height: s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = Brand.kaaba,
    );
    // Gold outline, so the black cube shows on the night dial.
    {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = palette.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top + s * 0.22, s, s * 0.13),
      Paint()..color = Brand.kaabaBand,
    );
    canvas.drawRect(
      Rect.fromLTWH(centre.dx + s * 0.12, rect.top + s * 0.5, s * 0.2, s * 0.5),
      Paint()..color = Brand.kaabaDoor,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.heading != heading ||
      old.qibla != qibla ||
      old.facing != facing ||
      old.palette != palette;
}
