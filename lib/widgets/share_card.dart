import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/content.dart';
import '../theme.dart';
import 'pattern.dart';

/// A picture-ready card: Arabic, Bangla, reference and the app name.
/// It always uses the same colours, whatever the phone's theme.
class ShareCard extends StatelessWidget {
  const ShareCard(this.item, {super.key, this.heading});

  final ContentItem item;

  /// Top-left label; "আজকের আয়াত" / "আজকের হাদিস" by default.
  final String? heading;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: banglaFont, fontFamilyFallback: fontFallback),
        child: _card(),
      ),
    );
  }

  Widget _card() {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 450),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.greenShare, Brand.deepEmerald, Brand.night],
        ),
      ),
      child: Stack(
        children: [
          const PatternLayer(color: Brand.lightGold, opacity: 0.09, cell: 46),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 30),
                    const SizedBox(width: 8),
                    Text(
                      heading ?? (item.isAyah ? 'আজকের আয়াত' : 'আজকের হাদিস'),
                      style: const TextStyle(
                        fontFamily: headingFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Brand.lightGold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.category,
                      style: TextStyle(
                        fontFamily: headingFont,
                        fontSize: 12,
                        color: Brand.onNight.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: Brand.onNight.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Brand.lightGold.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          item.arabic,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: arabicFont,
                            fontSize: item.isAyah ? 24 : 19,
                            height: 2.0,
                            color: Brand.cream,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: SizedBox.square(
                          dimension: 12,
                          child: CustomPaint(painter: _GoldStar()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.bangla,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: banglaFont,
                          fontSize: 14.5,
                          height: 1.7,
                          color: Brand.onNight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Brand.lightGold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'আয়াত রিমাইন্ডার · Ayah Reminder',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontSize: 11.5,
                    letterSpacing: 0.3,
                    color: Brand.onNight.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldStar extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      eightPointStar(size.center(Offset.zero), size.width / 2),
      Paint()..color = Brand.gold,
    );
  }

  @override
  bool shouldRepaint(_GoldStar old) => false;
}

/// Shows a preview of the image card with a share button.
Future<void> showShareSheet(BuildContext context, ContentItem item, {String? heading}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareSheet(item, heading),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet(this.item, this.heading);

  final ContentItem item;
  final String? heading;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = XFile.fromData(
        png!.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'ayah-reminder-${widget.item.id}.png',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], text: '${widget.item.title}\n— আয়াত রিমাইন্ডার'),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ছবি তৈরি করা যায়নি, আবার চেষ্টা করুন')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ছবি হিসেবে শেয়ার করুন', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'ফেসবুক, হোয়াটসঅ্যাপ বা যেকোনো অ্যাপে পাঠাতে পারবেন',
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radiusM),
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _key,
                    child: ShareCard(widget.item, heading: widget.heading),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded),
                label: const Text('শেয়ার করুন'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
