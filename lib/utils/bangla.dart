import '../models/content.dart';

const _weekdays = ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'];
const _months = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

/// e.g. "রবিবার, ২৭ সেপ্টেম্বর"
String banglaDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${toBanglaDigits(d.day)} ${_months[d.month - 1]}';

/// Greeting for the time of day.
String greeting(int hour) {
  if (hour >= 4 && hour < 12) return 'শুভ সকাল';
  if (hour >= 12 && hour < 15) return 'শুভ দুপুর';
  if (hour >= 15 && hour < 18) return 'শুভ বিকাল';
  if (hour >= 18 && hour < 20) return 'শুভ সন্ধ্যা';
  return 'শুভ রাত্রি';
}

const _hijriMonths = [
  'মুহাররম',
  'সফর',
  'রবিউল আউয়াল',
  'রবিউস সানি',
  'জমাদিউল আউয়াল',
  'জমাদিউস সানি',
  'রজব',
  'শাবান',
  'রমজান',
  'শাওয়াল',
  'জিলকদ',
  'জিলহজ',
];

/// Hijri (year, month 1–12, day) for a date, by the standard tabular Islamic
/// calendar (Kuwaiti algorithm). It is calculated, so it can differ by a day
/// from the moon-sighting date announced locally.
(int, int, int) hijriOf(DateTime d) {
  // Julian day number of the Gregorian date.
  final a = (14 - d.month) ~/ 12;
  final y = d.year + 4800 - a;
  final m = d.month + 12 * a - 3;
  final jd = d.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final month = (24 * l) ~/ 709;
  final day = l - (709 * month) ~/ 24;
  final year = 30 * n + j - 30;
  return (year, month, day);
}

/// e.g. "১০ রবিউস সানি ১৪৪৮ হিজরি"
String hijriDate(DateTime d) {
  final (y, m, day) = hijriOf(d);
  return '${toBanglaDigits(day)} ${_hijriMonths[m - 1]} ${toBanglaDigits(y)} হিজরি';
}
