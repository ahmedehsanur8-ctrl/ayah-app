import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/audio.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/item_view.dart';
import '../widgets/pattern.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// Shows one ayah or hadith full screen. The "আমি পড়েছি" button unlocks
/// after a 12 second countdown, so the reader takes a moment with the text.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.item, this.payload, this.fromReminder = false});

  final ContentItem item;
  final ReminderPayload? payload;
  final bool fromReminder;

  static const countdownSeconds = 12;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> with TickerProviderStateMixin {
  late final _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: ReadingScreen.countdownSeconds),
  )..forward();
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  bool get _ready => _countdown.isCompleted;

  @override
  void initState() {
    super.initState();
    _countdown.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
    // "আয়াতের তিলাওয়াতের শুরু" as the reminder sound: start the recitation.
    if (widget.fromReminder && AppState.instance.settings.reminderSound == 'tilawat') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AudioController.instance.playItem(widget.item);
      });
    }
  }

  /// Leaves the page (to the home screen when it was opened from a reminder).
  void _leave() {
    final settings = AppState.instance.settings;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => settings.setupDone ? const HomeShell() : const OnboardingScreen(),
        ),
      );
    }
  }

  /// "১০ মিনিট পরে": stop the sound and ring again in 10 minutes.
  Future<void> _snooze() async {
    await AudioController.instance.stop();
    await Reminders.snooze();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('১০ মিনিট পর আবার মনে করিয়ে দেওয়া হবে')));
    _leave();
  }

  @override
  void dispose() {
    // Stop this item's audio when the page closes.
    if (AudioController.instance.currentId == widget.item.id) {
      AudioController.instance.stop();
    }
    _countdown.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final settings = AppState.instance.settings;
    final p = widget.payload;
    final key = p != null
        ? '${p.dateKey}-${p.slot}'
        : '${dateKey(Reminders.nowDhaka())}-${widget.item.isAyah ? 'morning' : 'night'}';
    await settings.markRead(key);
    await Reminders.stopSound();
    await Reminders.dismissShown();
    if (!mounted) return;
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final heading = widget.item.isAyah ? 'আজকের আয়াত' : 'আজকের হাদিস';
    final canLeave = _ready || !widget.fromReminder;
    return PopScope(
      // From a reminder, leaving is only possible after the countdown.
      canPop: canLeave,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.readingTop, p.readingBottom],
            ),
          ),
          child: Stack(
            children: [
              PatternLayer(color: p.pattern, opacity: p.isDark ? 0.06 : 0.05, cell: 60),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Row(
                        children: [
                          if (canLeave)
                            IconButton(
                              tooltip: 'বন্ধ করুন',
                              icon: Icon(Icons.close_rounded, color: p.text),
                              onPressed: () => Navigator.of(context).maybePop(),
                            )
                          else
                            const SizedBox(width: 48),
                          Expanded(
                            child: Text(
                              heading,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FavoriteButton(widget.item),
                          ShareButton(widget.item),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FadeTransition(
                        opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOut)),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(child: CategoryChip(widget.item)),
                                const SizedBox(height: 14),
                                Center(
                                  child: ItemAudioButton(
                                    widget.item,
                                    label: widget.item.isAyah ? 'তিলাওয়াত শুনুন' : 'হাদিস শুনুন',
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ItemBody(widget.item),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, widget.fromReminder ? 4 : 18),
                      child: _CountdownButton(controller: _countdown, onPressed: _done),
                    ),
                    if (widget.fromReminder)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextButton.icon(
                          onPressed: _snooze,
                          icon: const Icon(Icons.snooze_rounded),
                          label: const Text('১০ মিনিট পরে'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill button with a circular countdown ring. Enabled when the ring is full.
class _CountdownButton extends StatelessWidget {
  const _CountdownButton({required this.controller, required this.onPressed});

  final AnimationController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ready = controller.isCompleted;
        final left = (ReadingScreen.countdownSeconds * (1 - controller.value)).ceil().clamp(0, 99);
        final fg = ready ? (p.isDark ? Brand.night : Colors.white) : p.text;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          height: 62,
          decoration: BoxDecoration(
            color: ready ? p.primary : p.surface,
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: ready ? p.primary : p.border),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(31),
              onTap: ready ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 46,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.square(
                            dimension: 42,
                            child: CircularProgressIndicator(
                              value: controller.value,
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: p.border,
                              color: ready ? Colors.transparent : p.accent,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: ready
                                ? Icon(
                                    Icons.check_rounded,
                                    key: const ValueKey('ok'),
                                    color: fg,
                                    size: 28,
                                  )
                                : Text(
                                    toBanglaDigits(left),
                                    key: const ValueKey('n'),
                                    style: TextStyle(
                                      fontFamily: headingFont,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                      color: p.text,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        ready ? 'আমি পড়েছি' : 'মনোযোগ দিয়ে পড়ুন…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: headingFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: ready ? fg : p.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 46),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
