import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/content.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/item_view.dart';
import 'home_shell.dart';
import 'setup_screen.dart';

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

class _ReadingScreenState extends State<ReadingScreen> {
  int _left = ReadingScreen.countdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _done() async {
    final settings = AppState.instance.settings;
    final p = widget.payload;
    final key = p != null
        ? '${p.dateKey}-${p.slot}'
        : '${dateKey(Reminders.nowDhaka())}-${widget.item.isAyah ? 'morning' : 'night'}';
    await settings.markRead(key);
    await Reminders.dismissShown();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              settings.setupDone ? const HomeShell() : const SetupScreen(firstTime: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _left <= 0;
    final heading = widget.item.isAyah ? 'আজকের আয়াত' : 'আজকের হাদিস';
    return PopScope(
      // From a reminder, leaving is only possible after the countdown.
      canPop: ready || !widget.fromReminder,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.deepGreen, AppColors.green, Color(0xFF2E8A60)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      if (!widget.fromReminder || ready)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          heading,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ItemBody(widget.item),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.deepGreen,
                        disabledBackgroundColor: Colors.white24,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: ready ? _done : null,
                      icon: Icon(ready ? Icons.check_circle : Icons.hourglass_top),
                      label: Text(
                        ready
                            ? 'আমি পড়েছি'
                            : 'মনোযোগ দিয়ে পড়ুন... ${toBanglaDigits(_left)} সেকেন্ড',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
