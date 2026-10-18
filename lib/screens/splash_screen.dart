import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/pattern.dart';

/// Logo on a soft geometric pattern, with a short fade-in, then [next].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );
  late final _scale = Tween(begin: 0.86, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.8, curve: Curves.easeOutBack),
    ),
  );
  late final _text = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, _, _) => widget.next,
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.deepEmerald,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Brand.greenBright, Brand.deepEmerald, Brand.night],
          ),
        ),
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fade,
              child: const Stack(
                children: [PatternLayer(color: Brand.lightGold, opacity: 0.07, cell: 64)],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color: Brand.gold.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const AppLogo(size: 124),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: _text,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_text),
                      child: const Column(
                        children: [
                          Text(
                            'আয়াত রিমাইন্ডার',
                            style: TextStyle(
                              fontFamily: headingFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              color: Brand.onNight,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'প্রতিদিন আল্লাহর বাণীর সাথে',
                            style: TextStyle(
                              fontFamily: headingFont,
                              fontSize: 15,
                              color: Brand.lightGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
