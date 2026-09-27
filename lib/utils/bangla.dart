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
