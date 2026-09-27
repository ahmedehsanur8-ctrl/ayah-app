import 'package:flutter/material.dart';

import '../services/audio.dart';
import '../services/system_settings.dart';
import '../theme.dart';

/// Play / stop button for an ayah, hadith or story.
///
/// [id] is the item or story id; [onToggle] starts or stops its audio.
class AudioButton extends StatefulWidget {
  const AudioButton({super.key, required this.id, required this.onToggle, this.color, this.label});

  final String id;
  final Future<void> Function() onToggle;
  final Color? color;

  /// When set, shows a wide pill button with this text instead of an icon.
  final String? label;

  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> {
  final _audio = AudioController.instance;
  int _seenProblems = AudioController.instance.problemCount;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_onChange);
  }

  @override
  void dispose() {
    _audio.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (_audio.problemCount != _seenProblems && _audio.currentId == widget.id) {
      _seenProblems = _audio.problemCount;
      if (_audio.problem == AudioProblem.offline) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('আরবি তিলাওয়াত প্রথমবার শুনতে ইন্টারনেট সংযোগ দরকার।')),
          );
      } else if (_audio.problem == AudioProblem.noBanglaVoice) {
        showNoBanglaVoiceDialog(context);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = _audio.isActive(widget.id);
    final loading = active && _audio.status == AudioStatus.loading;
    final color = widget.color ?? p.primary;
    final icon = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
          )
        : Icon(active ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: color);
    if (widget.label == null) {
      return IconButton(
        tooltip: active ? 'থামান' : 'শুনুন',
        onPressed: widget.onToggle,
        icon: icon,
      );
    }
    return OutlinedButton.icon(
      onPressed: widget.onToggle,
      icon: icon,
      label: Text(active ? 'থামান' : widget.label!),
    );
  }
}

/// Explains in simple Bangla how to install the phone's Bangla voice.
Future<void> showNoBanglaVoiceDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('বাংলা কণ্ঠ পাওয়া যায়নি'),
      content: const SingleChildScrollView(
        child: Text(
          'বাংলা অর্থ ও হাদিস শোনার জন্য ফোনে বাংলা কণ্ঠ (Text-to-speech) দরকার। '
          'এটি একবারই ইনস্টল করতে হয়, বিনামূল্যে:\n\n'
          '১. Play Store খুলে "Speech Recognition & Synthesis from Google" অ্যাপটি ইনস্টল বা আপডেট করুন।\n\n'
          '২. নিচের "সেটিংস খুলুন" বোতামে চাপ দিন (অথবা ফোনের Settings → System → Languages & input → Text-to-speech output)।\n\n'
          '৩. Preferred engine হিসেবে "Speech Services by Google" বেছে নিন।\n\n'
          '৪. তার পাশের ⚙ চিহ্নে চাপ দিয়ে "Install voice data" → "বাংলা (বাংলাদেশ)" বেছে নিয়ে ডাউনলোড করুন।\n\n'
          '৫. অ্যাপে ফিরে এসে আবার ▶ চাপুন।',
          style: TextStyle(height: 1.6),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('পরে')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            SystemSettings.openTtsSettings();
          },
          child: const Text('সেটিংস খুলুন'),
        ),
      ],
    ),
  );
}
