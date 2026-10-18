#!/usr/bin/env python3
"""Builds the সহজ আরবি (Learn Arabic from Bangla) Level 1 lessons.

All lesson text, examples and exercises below are written for this app.
Quran words and ayat are taken from the app's own Tanzil Uthmani text
(assets/quran/arabic.txt.gz): every word written here is looked up there and
replaced by the exact Tanzil spelling, with its surah:ayah.

Writes:
  assets/arabic/level1.json          lessons, items and games for the app
  assets/arabic_audio/README.md      what the audio folder is for
  docs/ARABIC_AUDIO_LIST.md          the recording list for the qari

Run: python3 tools/build_arabic_lessons.py
"""

import collections
import gzip
import json
import pathlib
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent

# ------------------------------------------------------------------ Quran text

LINES = gzip.open(ROOT / 'assets/quran/arabic.txt.gz', 'rt', encoding='utf-8').read().split('\n')
META = json.loads((ROOT / 'assets/quran/meta.json').read_text(encoding='utf-8'))


def ref_of(index):
    for s in META['surahs']:
        if s['start'] <= index < s['start'] + s['ayahs']:
            return f"{s['n']}:{index - s['start'] + 1}"
    raise ValueError(index)


def ayah(s, a):
    return LINES[META['surahs'][s - 1]['start'] + a - 1]


def norm(w):
    """Same word, ignoring tatweel and the order of stacked marks."""
    w = w.replace('ـ', '')
    out, marks = [], []
    for ch in w:
        if unicodedata.combining(ch):
            marks.append(ch)
        else:
            out += sorted(marks)
            marks = []
            out.append(ch)
    return ''.join(out + sorted(marks))


TOKENS = {}
for i, line in enumerate(LINES):
    for t in line.split():
        TOKENS.setdefault(norm(t), (t, ref_of(i)))

MISSING = []


def quran_word(w):
    """The Tanzil spelling of [w] and where it first appears."""
    hit = TOKENS.get(norm(w))
    if not hit:
        MISSING.append(w)
        return w, ''
    return hit


# ------------------------------------------------------------------ letters

# n, letter, file key, name, name used in games, consonant for syllables, how to say it
LETTERS = [
    (1, 'ا', 'alif', 'আলিফ', 'আলিফ', '', 'আলিফ নিজে কোনো আওয়াজ দেয় না। আগের অক্ষরের আওয়াজকে টেনে লম্বা করে। মাথায় বা পায়ে ছোট্ট হামযা (ء) বসলে তখন আ, ই, উ বলে।'),
    (2, 'ب', 'ba', 'বা', 'বা', 'ব', 'দুই ঠোঁট মিলিয়ে বলুন। নিচে একটি ফোঁটা।'),
    (3, 'ت', 'ta', 'তা', 'তা', 'ত', 'জিভের আগা ওপরের সামনের দাঁতের গোড়ায় ছুঁইয়ে নরম করে বলুন। ওপরে দুটি ফোঁটা।'),
    (4, 'ث', 'tha', 'ছা', 'ছা', 'ছ', 'জিভের আগা একটু বের করে ওপরের দাঁতে হালকা ছুঁইয়ে বাতাস ছাড়ুন, ইংরেজি think শব্দের th-এর মতো। ওপরে তিনটি ফোঁটা।'),
    (5, 'ج', 'jim', 'জীম', 'জীম', 'জ', 'জিভের মাঝখান তালুতে লাগিয়ে বলুন। পেটের ভেতরে একটি ফোঁটা।'),
    (6, 'ح', 'haa', 'হা', 'হা (মাঝ-গলার)', 'হ', 'গলার মাঝখান একটু চেপে পরিষ্কার হ বলুন, যেন গরম চায়ে ফুঁ দিচ্ছেন। কোনো ফোঁটা নেই।'),
    (7, 'خ', 'kha', 'খা', 'খা', 'খ', 'গলার ওপরের দিক থেকে ঘষা খ, মুখ ভরে মোটা করে। ওপরে একটি ফোঁটা।'),
    (8, 'د', 'dal', 'দাল', 'দাল', 'দ', 'জিভের আগা ওপরের দাঁতের গোড়ায় লাগিয়ে নরম দ।'),
    (9, 'ذ', 'dhal', 'যাল', 'যাল', 'য', 'জিভের আগা দাঁতের ফাঁকে রেখে বলুন, ইংরেজি this শব্দের th-এর মতো। ওপরে একটি ফোঁটা।'),
    (10, 'ر', 'ra', 'রা', 'রা', 'র', 'জিভের আগা দিয়ে র।'),
    (11, 'ز', 'zay', 'যা', 'যা (ইংরেজি z)', 'য', 'মৌমাছির গুনগুনের মতো, ইংরেজি z-এর আওয়াজ। ওপরে একটি ফোঁটা।'),
    (12, 'س', 'sin', 'সীন', 'সীন', 'স', 'পাতলা শিস দেওয়া স, ইংরেজি s-এর মতো। কোনো ফোঁটা নেই।'),
    (13, 'ش', 'shin', 'শীন', 'শীন', 'শ', 'বাংলা শ-এর মতো। ওপরে তিনটি ফোঁটা।'),
    (14, 'ص', 'sad', 'সোয়াদ', 'সোয়াদ', 'স', 'মোটা স। জিভের পেছন একটু উঁচু করে, মুখ ভরে বলুন।'),
    (15, 'ض', 'dad', 'দোয়াদ', 'দোয়াদ', 'দ', 'মোটা দ। জিভের পাশ ওপরের মাড়ির দাঁতে লাগিয়ে মুখ ভরে বলুন। ওপরে একটি ফোঁটা।'),
    (16, 'ط', 'taa', 'ত্বোয়া', 'ত্বোয়া', 'ত্ব', 'মোটা ত। জিভের আগা দাঁতের গোড়ায় জোরে লাগিয়ে মুখ ভরে বলুন।'),
    (17, 'ظ', 'zaa', 'যোয়া', 'যোয়া', 'য', 'মোটা যাল। জিভের আগা দাঁতের ফাঁকে রেখে মুখ ভরে বলুন। ওপরে একটি ফোঁটা।'),
    (18, 'ع', 'ain', 'আইন', 'আইন', '', 'গলার মাঝখান চেপে আ। বাংলায় এমন আওয়াজ নেই, তাই বারবার শুনে শিখুন।'),
    (19, 'غ', 'ghain', 'গাইন', 'গাইন', 'গ', 'গড়গড়া করার মতো, গলার ওপরের দিক থেকে মোটা গ। ওপরে একটি ফোঁটা।'),
    (20, 'ف', 'fa', 'ফা', 'ফা', 'ফ', 'নিচের ঠোঁট ওপরের দাঁতে ছুঁইয়ে, ইংরেজি f-এর মতো। ওপরে একটি ফোঁটা।'),
    (21, 'ق', 'qaf', 'ক্বাফ', 'ক্বাফ', 'ক্ব', 'জিভের একেবারে পেছন দিয়ে, গলার কাছ থেকে মোটা ক। ওপরে দুটি ফোঁটা।'),
    (22, 'ك', 'kaf', 'কাফ', 'কাফ', 'ক', 'সাধারণ পাতলা ক। মাঝে ছোট্ট একটা দাগ থাকে।'),
    (23, 'ل', 'lam', 'লাম', 'লাম', 'ল', 'জিভের আগা দিয়ে ল।'),
    (24, 'م', 'mim', 'মীম', 'মীম', 'ম', 'দুই ঠোঁট মিলিয়ে ম।'),
    (25, 'ن', 'nun', 'নূন', 'নূন', 'ন', 'জিভের আগা দিয়ে ন। ওপরে একটি ফোঁটা।'),
    (26, 'ه', 'ha', 'হা', 'হা (গভীর গলার)', 'হ', 'গলার একেবারে ভেতর থেকে হালকা হ, যেন আয়নায় ভাপ দিচ্ছেন।'),
    (27, 'و', 'waw', 'ওয়াও', 'ওয়াও', 'ওয়', 'ঠোঁট গোল করে ওয়া।'),
    (28, 'ي', 'ya', 'ইয়া', 'ইয়া', 'ইয়', 'বাংলা ইয়া-এর মতো। নিচে দুটি ফোঁটা।'),
    (29, 'ء', 'hamza', 'হামযা', 'হামযা', '', 'গলা এক মুহূর্ত বন্ধ করে হঠাৎ আ, যেমন বাংলায় আচমকা বলুন "আ!"। একা বসে, আবার আলিফ, ওয়াও বা ইয়ার ওপরেও বসে।'),
]
BY_N = {l[0]: l for l in LETTERS}
HEAVY = {7, 14, 15, 16, 17, 19, 21}

FATHA, KASRA, DAMMA, SUKUN, SHADDA = 'َ', 'ِ', 'ُ', 'ْ', 'ّ'
FATHATAN, KASRATAN, DAMMATAN = 'ً', 'ٍ', 'ٌ'

ITEMS = {}
AUDIO = []  # (file, arabic, how to say it in Bangla, what it is)


def add_item(iid, **kw):
    ITEMS.setdefault(iid, {k: v for k, v in kw.items() if v not in (None, '')})
    a = kw.get('audio')
    if a and not any(x[0] == a for x in AUDIO):
        AUDIO.append((a, kw['ar'], kw.get('bn', ''), kw.get('_what', '')))
    ITEMS[iid].pop('_what', None)
    return iid


def fnum(n):
    return f'{n:02d}_{BY_N[n][2]}'


def letter_item(n):
    _, ch, _, name, label, _, tip = BY_N[n]
    return add_item(f'L{n:02d}', ar=ch, bn=label, name=name, tip=tip,
                    audio=f'name_{fnum(n)}.mp3', kind='letter', _what='অক্ষরের নাম')


def vowel_bn(n, v):
    """Bangla way of saying letter [n] with vowel v (a, i, u, an, in, un, aa, ii, uu)."""
    c = BY_N[n][5]
    if n in (1, 18, 29):
        base = {'a': 'আ', 'i': 'ই', 'u': 'উ'}
    elif n == 27:
        base = {'a': 'ওয়া', 'i': 'ওয়ি', 'u': 'ওয়ু'}
    elif n == 28:
        base = {'a': 'ইয়া', 'i': 'ইয়ি', 'u': 'ইয়ু'}
    elif n in (14, 15, 16, 17):
        base = {'a': c + 'োয়া', 'i': c + 'ি', 'u': c + 'ু'}
    else:
        base = {'a': c + 'া', 'i': c + 'ি', 'u': c + 'ু'}
    short = v[0]
    s = base[short]
    if v in ('an', 'in', 'un'):
        return s + 'ন'
    if v == 'aa':
        return s + '-আ'
    if v == 'ii':
        return s.replace('ি', 'ী') if 'ি' in s else s + 'ই'
    if v == 'uu':
        return s.replace('ু', 'ূ') if 'ু' in s else s + 'উ'
    return s


def syllable(n, v):
    """Letter [n] with a vowel. Alif takes a hamza to carry the vowel."""
    ch = BY_N[n][1]
    mark = {'a': FATHA, 'i': KASRA, 'u': DAMMA, 'an': FATHATAN, 'in': KASRATAN,
            'un': DAMMATAN}.get(v)
    if n == 1:
        ch = 'إ' if v in ('i', 'in') else 'أ'
    if v == 'an':
        ar = ch + FATHATAN + ('' if n in (29,) else 'ا')
    elif v == 'aa':
        ar = ch + FATHA + 'ا'
    elif v == 'ii':
        ar = ch + KASRA + 'ي'
    elif v == 'uu':
        ar = ch + DAMMA + 'و'
    else:
        ar = ch + mark
    what = {'a': 'যবর', 'i': 'যের', 'u': 'পেশ', 'an': 'দুই যবর', 'in': 'দুই যের',
            'un': 'দুই পেশ', 'aa': 'লম্বা আ', 'ii': 'লম্বা ঈ', 'uu': 'লম্বা ঊ'}[v]
    return add_item(f'S{n:02d}{v}', ar=ar, bn=vowel_bn(n, v), kind='syllable',
                    audio=f'{fnum(n)}_{v}.mp3', _what=f'{BY_N[n][3]} + {what}')


def word(key, ar, bn, meaning='', note=''):
    ar, ref = quran_word(ar)
    return add_item(f'W_{key}', ar=ar, bn=bn, meaning=meaning, ref=ref, note=note,
                    kind='word', audio=f'w_{key}.mp3', _what='কুরআনের শব্দ')


def letters_of(iid):
    """Tiles for building a word: each letter with its marks."""
    parts = []
    for ch in ITEMS[iid]['ar']:
        if ch == 'ـ':
            continue
        if unicodedata.combining(ch) and parts:
            parts[-1] += ch
        else:
            parts.append(ch)
    return parts


# ------------------------------------------------------------------ games

def listen(items, pool=None, rounds=6):
    return {'type': 'listen', 'items': items, 'pool': pool or items, 'rounds': rounds}


def match(items, right='bn'):
    return {'type': 'match', 'items': items, 'right': right}


def arrange(puzzles, hint=''):
    return {'type': 'arrange', 'hint': hint, 'puzzles': puzzles}


def build_word(iid):
    return {'item': iid, 'parts': letters_of(iid)}


def order(ids):
    return {'item': None, 'parts': [ITEMS[i]['ar'] for i in ids], 'label': ''}


def trace(items):
    return {'type': 'trace', 'items': items}


def quiz(questions):
    return {'type': 'quiz', 'questions': questions}


def q(text, options, answer=0, ar='', options_ar=True, explain=''):
    return {'q': text, 'ar': ar, 'options': options, 'answer': answer,
            'optionsAr': options_ar, 'explain': explain}


LESSONS = []


def lesson(title, subtitle, intro, cards, games, minutes=4, extra=None, ayahs=None):
    n = len(LESSONS) + 1
    cards = list(dict.fromkeys(cards))
    for g in games:
        for k in ('items', 'pool'):
            if k in g:
                g[k] = list(dict.fromkeys(g[k]))
    d = {'id': f'1-{n:02d}', 'n': n, 'title': title, 'subtitle': subtitle, 'minutes': minutes,
         'intro': intro, 'cards': cards, 'games': games}
    if extra:
        d['extra'] = extra
    if ayahs:
        d['ayahs'] = ayahs
    LESSONS.append(d)


# ------------------------------------------------------------------ lessons 1-6: letters

GROUPS = [
    ([1, 2, 3, 4], 'আলিফ থেকে ছা', 'ا ب ت ث',
     ['আরবি লেখা ডান দিক থেকে বাঁ দিকে যায়। বাংলার উল্টো দিকে!',
      'আজ চারটি অক্ষর: আলিফ, বা, তা, ছা। খেয়াল করুন, বা, তা, ছা দেখতে একই রকম নৌকার মতো। পার্থক্য শুধু ফোঁটায়: বা-এর নিচে এক ফোঁটা, তা-এর ওপরে দুই, ছা-এর ওপরে তিন।',
      'প্রতিটি অক্ষরে চাপ দিয়ে নাম শুনুন, তারপর নিজে জোরে বলুন।']),
    ([5, 6, 7, 8, 9], 'জীম থেকে যাল', 'ج ح خ د ذ',
     ['জীম, হা, খা একই পরিবারের। তিনটিরই পেট একই রকম। ফোঁটা না থাকলে হা, পেটের ভেতরে ফোঁটা হলে জীম, মাথায় ফোঁটা হলে খা।',
      'দাল আর যাল যমজ ভাই। যালের মাথায় একটি ফোঁটা বেশি।',
      'হা (ح) গলার মাঝখান থেকে আসে, আর খা আসে গলার ওপরের দিক থেকে। বাংলায় এমন আওয়াজ কম, তাই কয়েকবার শুনে বলুন।']),
    ([10, 11, 12, 13, 14], 'রা থেকে সোয়াদ', 'ر ز س ش ص',
     ['রা আর যা ছোট্ট বাঁকা দাগের মতো। যা-এর মাথায় একটি ফোঁটা।',
      'সীন দেখতে তিনটি ছোট দাঁতের মতো। শীনের দাঁতের ওপরে তিনটি ফোঁটা।',
      'সোয়াদ একটি মোটা অক্ষর। মোটা অক্ষর বলার সময় মুখ ভরে, একটু গম্ভীর করে বলতে হয়।']),
    ([15, 16, 17, 18, 19], 'দোয়াদ থেকে গাইন', 'ض ط ظ ع غ',
     ['দোয়াদ হলো সোয়াদের মতো, মাথায় একটি ফোঁটা। ত্বোয়া আর যোয়া-ও জোড়া: যোয়ার মাথায় একটি ফোঁটা।',
      'দোয়াদ, ত্বোয়া, যোয়া তিনটিই মোটা অক্ষর। মুখ ভরে বলুন।',
      'আইন আর গাইনও জোড়া। আইন আসে গলার মাঝখান থেকে, গাইন গলার ওপরের দিক থেকে।']),
    ([20, 21, 22, 23, 24], 'ফা থেকে মীম', 'ف ق ك ل م',
     ['ফা আর ক্বাফ দেখতে কাছাকাছি। ফা-এর মাথায় এক ফোঁটা, ক্বাফের দুই ফোঁটা, আর ক্বাফের লেজ নিচে বেশি নামে।',
      'ক্বাফ মোটা ক, গলার কাছ থেকে। কাফ পাতলা ক, মুখের সামনের দিক থেকে।',
      'লাম লম্বা লাঠির মতো ওপরে ওঠে। মীম ছোট্ট গোল মাথার মতো।']),
    ([25, 26, 27, 28, 29], 'নূন থেকে ইয়া', 'ن ه و ي ء',
     ['নূন ছোট বাটির মতো, ওপরে একটি ফোঁটা। হা (ه) গোল, আর এটি গলার একেবারে ভেতর থেকে আসে।',
      'ওয়াও আর ইয়া দুটি বিশেষ অক্ষর: কখনো নিজে আওয়াজ দেয়, কখনো আগের আওয়াজ লম্বা করে। সেটা পরে শিখবে।',
      'হামযা (ء) ছোট্ট একটি চিহ্ন। এটি একা বসে, আবার আলিফ, ওয়াও বা ইয়ার ওপরেও বসে। এই পাঠে আরবির সব অক্ষর শেষ হলো। মাশাআল্লাহ!']),
]

ALL_LETTERS = [letter_item(n) for n in range(1, 30)]

for nums, title, sub, intro in GROUPS:
    ids = [letter_item(n) for n in nums]
    so_far = [letter_item(n) for n in range(1, max(nums) + 1)]
    games = [
        listen(ids, pool=so_far if len(so_far) > 4 else ids, rounds=6),
        match(ids, right='name'),
        arrange([order([i for i in ids if i != 'L29'])], hint='বর্ণমালার ক্রমে ডান থেকে বাঁয়ে সাজান'),
        trace([i for i in ids if i != 'L29'][:3]),
    ]
    if 29 in nums:  # hamza is not in the alphabet order
        games[2] = arrange([order(['L25', 'L26', 'L27', 'L28'])],
                           hint='বর্ণমালার ক্রমে ডান থেকে বাঁয়ে সাজান')
    lesson(title, sub, intro, ids, games, minutes=4)

# ------------------------------------------------------------------ 7: similar sounds

PAIRS = [(3, 16), (12, 14), (4, 12), (6, 26), (22, 21), (8, 15), (9, 11), (9, 17), (29, 18)]
lesson(
    'কাছাকাছি আওয়াজ', 'ت ط · س ص · ح ه · ك ق',
    ['কিছু অক্ষরের আওয়াজ বাংলায় শুনতে একই রকম লাগে, কিন্তু আরবিতে আলাদা। ভুল অক্ষর বললে শব্দের অর্থও বদলে যেতে পারে।',
     'মনে রাখার সহজ উপায়: মোটা অক্ষর (খ ص ض ط ظ غ ق) মুখ ভরে বলুন, পাতলা অক্ষর হালকা করে বলুন।',
     'জোড়া: তা–ত্বোয়া, সীন–সোয়াদ, ছা–সীন, হা (ح)–হা (ه), কাফ–ক্বাফ, দাল–দোয়াদ, যাল–যা–যোয়া, হামযা–আইন।'],
    [letter_item(n) for pair in PAIRS for n in pair],
    [
        listen([letter_item(n) for n in (16, 14, 26, 21, 15, 17, 18)],
               pool=[letter_item(n) for pair in PAIRS for n in pair], rounds=8),
        match([letter_item(n) for n in (3, 16, 12, 14, 21)], right='name'),
        quiz([
            q('কোনটি মোটা ত?', ['ط', 'ت', 'ث', 'د'], 0),
            q('কোনটি মোটা স?', ['ص', 'س', 'ش', 'ث'], 0),
            q('কোন হা গলার মাঝখান থেকে আসে?', ['ح', 'ه', 'خ', 'ج'], 0,
              explain='ح গলার মাঝখান থেকে, ه গলার একেবারে ভেতর থেকে।'),
            q('কোনটি মোটা ক?', ['ق', 'ك', 'ف', 'غ'], 0),
            q('ইংরেজি z-এর মতো আওয়াজ কোনটির?', ['ز', 'ذ', 'ظ', 'ر'], 0),
        ]),
    ],
    minutes=5,
)

# ------------------------------------------------------------------ 8: shapes

SHAPE_LETTERS = [2, 5, 12, 18, 20, 22, 24, 26, 28]


def forms(n):
    ch = BY_N[n][1]
    return {'iso': ch, 'ini': ch + 'ـ', 'med': 'ـ' + ch + 'ـ', 'fin': 'ـ' + ch}


for n in SHAPE_LETTERS:
    f = forms(n)
    for k, bn in (('ini', 'শুরুর রূপ'), ('med', 'মাঝের রূপ'), ('fin', 'শেষের রূপ')):
        add_item(f'F{n:02d}{k}', ar=f[k], bn=f'{BY_N[n][3]}: {bn}', kind='form')

lesson(
    'অক্ষরের তিন রূপ', 'শুরু · মাঝ · শেষ',
    ['শব্দের ভেতরে অক্ষর পাশের অক্ষরের সাথে হাত ধরে। তাই একই অক্ষর শুরুতে, মাঝে আর শেষে একটু আলাদা দেখায়।',
     'সাধারণত মাথা বা লেজ ছোট হয়ে যায়, কিন্তু ফোঁটা একই জায়গায় থাকে। ফোঁটা দেখেই অক্ষর চেনা যায়!',
     'নিচের সারিতে প্রতিটি অক্ষরের একা রূপ, শুরুর রূপ, মাঝের রূপ আর শেষের রূপ দেখুন। হা (ه) আর আইন (ع) সবচেয়ে বেশি বদলায়।'],
    [letter_item(n) for n in SHAPE_LETTERS],
    [
        {'type': 'match', 'items': [letter_item(n) for n in (2, 5, 18, 26, 22)], 'right': 'form:med'},
        quiz([
            q('শব্দের শুরুতে ب কেমন দেখায়?', ['بـ', 'ـب', 'ـهـ', 'عـ'], 0),
            q('মাঝের রূপে এটি কোন অক্ষর? ـعـ', ['ع', 'غ', 'ه', 'ف'], 0),
            q('শব্দের শেষে ي কেমন দেখায়?', ['ـي', 'يـ', 'ـب', 'ـن'], 0),
            q('এটি কোন অক্ষর? ـهـ', ['ه', 'ع', 'م', 'ك'], 0),
            q('শব্দের শুরুতে ك কেমন দেখায়?', ['كـ', 'ـك', 'لـ', 'فـ'], 0),
        ]),
        trace([letter_item(n) for n in (18, 26, 22)]),
    ],
    minutes=5,
    extra={'forms': [forms(n) for n in SHAPE_LETTERS]},
)

# ------------------------------------------------------------------ 9: joining

J1 = word('baab', 'بَابٍ', 'বা-বিন', 'দরজা')
J2 = word('walad', 'وَلَدٌ', 'ওয়ালাদুন', 'সন্তান')
J3 = word('kataba', 'كَتَبَ', 'কাতাবা', 'তিনি লিখেছেন')
J4 = word('daaru', 'دَارُ', 'দা-রু', 'ঘর, বাড়ি')
J5 = word('rasul', 'رَسُولٌ', 'রাসূ-লুন', 'রাসূল, বার্তাবাহক')
lesson(
    'অক্ষর জোড়া লাগাই', 'কোন ৬টি অক্ষর বাঁয়ে জোড়ে না',
    ['বেশিরভাগ অক্ষর দুই দিকেই হাত ধরে: ডানের অক্ষরের সাথেও, বাঁয়ের অক্ষরের সাথেও।',
     'কিন্তু ৬টি অক্ষর শুধু ডান দিকে হাত ধরে, বাঁ দিকে ধরে না: ا د ذ ر ز و। এদের পরের অক্ষর নতুন করে শুরু হয়।',
     'তাই بَابٍ শব্দে আলিফের পরে ফাঁক, আর وَلَدٌ শব্দে ওয়াওয়ের পরে ফাঁক দেখবে।'],
    [J1, J2, J3, J4, J5],
    [
        arrange([build_word(J3), build_word(J1), build_word(J2)], hint='অক্ষরগুলো সাজিয়ে শব্দ বানান'),
        quiz([
            q('কোন অক্ষর বাঁ দিকে জোড়া লাগে না?', ['د', 'ب', 'م', 'س'], 0),
            q('কোন অক্ষর বাঁ দিকে জোড়া লাগে না?', ['و', 'ك', 'ن', 'ع'], 0),
            q('এই ৬টির দলে কোনটি নেই?', ['ل', 'ا', 'ر', 'ز'], 0,
              explain='ا د ذ ر ز و — এই ছয়টি বাঁয়ে জোড়ে না। ل দুই দিকেই জোড়ে।'),
        ]),
        match([J1, J2, J3, J4], right='meaning'),
    ],
    minutes=4,
)

# ------------------------------------------------------------------ 10-12: harakat

ALPHA = list(range(1, 29))

VOWEL_LESSONS = [
    ('a', 'যবর (ফাতহা)', 'অক্ষরের ওপরে ছোট্ট তেরছা দাগ: আ',
     ['যবর হলো অক্ষরের ওপরে ছোট্ট একটি তেরছা দাগ ( َ )। যবর থাকলে অক্ষরের সাথে "আ" যোগ হয়।',
      'بَ = বা, تَ = তা, مَ = মা। খুব ছোট করে বলুন, টেনে নয়।',
      'মোটা অক্ষরের (خ ص ض ط ظ غ ق) যবর একটু "ও"-র দিকে ঝোঁকে: صَ = সোয়া, طَ = ত্বোয়া। শুনে মিলিয়ে নিন।'],
     [('khalaqa', 'خَلَقَ', 'খালাক্বা', 'তিনি সৃষ্টি করেছেন'),
      ('jaala', 'جَعَلَ', 'জা\'আলা', 'তিনি বানিয়েছেন'),
      ('amara', 'أَمَرَ', 'আমারা', 'তিনি আদেশ করেছেন'),
      ('faala', 'فَعَلَ', 'ফা\'আলা', 'সে করল'),
      ('dhahaba', 'ذَهَبَ', 'যাহাবা', 'সে চলে গেল')]),
    ('i', 'যের (কাসরা)', 'অক্ষরের নিচে ছোট্ট তেরছা দাগ: ই',
     ['যের হলো অক্ষরের নিচে ছোট্ট একটি তেরছা দাগ ( ِ )। যের থাকলে অক্ষরের সাথে "ই" যোগ হয়।',
      'بِ = বি, تِ = তি, مِ = মি।',
      'এখন যবর আর যের মিশিয়ে কুরআনের শব্দ পড়ুন: عَلِمَ = আলিমা (সে জানল)।'],
     [('alima', 'عَلِمَ', 'আলিমা', 'সে জানল'),
      ('samia', 'سَمِعَ', 'সামি\'আ', 'সে শুনল'),
      ('shahida', 'شَهِدَ', 'শাহিদা', 'সে সাক্ষ্য দিল'),
      ('hafiza', 'حَفِظَ', 'হাফিযা', 'সে রক্ষা করল'),
      ('malik', 'مَلِكِ', 'মালিকি', 'মালিক, অধিপতি')]),
    ('u', 'পেশ (দাম্মা)', 'অক্ষরের ওপরে ছোট্ট ওয়াও: উ',
     ['পেশ দেখতে অক্ষরের ওপরে ছোট্ট একটি ওয়াওয়ের মতো ( ُ )। পেশ থাকলে অক্ষরের সাথে "উ" যোগ হয়।',
      'بُ = বু, تُ = তু, مُ = মু। ঠোঁট একটু গোল করুন।',
      'এখন তিনটি চিহ্ন মিলিয়ে পড়ুন: كُتِبَ = কুতিবা (লেখা হয়েছে)।'],
     [('kutiba', 'كُتِبَ', 'কুতিবা', 'লেখা হয়েছে, নির্ধারিত হয়েছে'),
      ('khuliqa', 'خُلِقَ', 'খুলিক্বা', 'সৃষ্টি করা হয়েছে'),
      ('qutila', 'قُتِلَ', 'ক্বুতিলা', 'নিহত হলো'),
      ('huwa', 'هُوَ', 'হুওয়া', 'তিনি, সে'),
      ('rusul', 'رُسُلُ', 'রুসুলু', 'রাসূলগণ')]),
]

for v, title, sub, intro, words in VOWEL_LESSONS:
    syl = [syllable(n, v) for n in ALPHA]
    ws = [word(k, ar, bn, m) for k, ar, bn, m in words]
    lesson(
        title, sub, intro, syl + ws,
        [
            listen(syl, rounds=8),
            match(syl[1:13:2] if v != 'u' else syl[13:28:3], right='bn'),
            arrange([build_word(w) for w in ws[:3]], hint='অক্ষর সাজিয়ে শব্দ বানান, ডান থেকে বাঁয়ে'),
            match(ws, right='meaning'),
        ],
        minutes=5,
    )

# ------------------------------------------------------------------ 13: tanween

TAN_LETTERS = [2, 8, 10, 12, 18, 24, 20, 21]
tan = [syllable(n, v) for n in TAN_LETTERS for v in ('an', 'in', 'un')]
tw = [
    word('ahad', 'أَحَدٌ', 'আহাদুন', 'এক, একক'),
    word('ilm', 'عِلْمٌ', 'ইলমুন', 'জ্ঞান'),
    word('rahma', 'رَحْمَةً', 'রাহমাতান', 'দয়া, রহমত'),
    word('sabab', 'سَبَبًا', 'সাবাবান', 'উপায়, পথ'),
    word('hudan', 'هُدًى', 'হুদান', 'পথনির্দেশ'),
]
lesson(
    'তানবীন (দুই যবর, দুই যের, দুই পেশ)', 'শেষে একটা নরম "ন"',
    ['কখনো শব্দের শেষ অক্ষরে চিহ্ন দুটি করে থাকে। একে তানবীন বলে। তানবীন মানে শেষে একটা "ন" আওয়াজ যোগ হবে, যদিও ن লেখা নেই।',
     'দুই যবর ( ً ) = আন, দুই যের ( ٍ ) = ইন, দুই পেশ ( ٌ ) = উন। যেমন: بًا = বান, بٍ = বিন, بٌ = বুন।',
     'দুই যবরের পরে সাধারণত একটি আলিফ লেখা থাকে। সেই আলিফ পড়া হয় না, শুধু দেখায় যে এখানে দুই যবর।'],
    tan + tw,
    [
        listen(tan, rounds=8),
        match([syllable(n, v) for n, v in ((2, 'an'), (8, 'in'), (10, 'un'), (24, 'an'), (21, 'in'))], right='bn'),
        arrange([build_word(tw[0]), build_word(tw[3])], hint='অক্ষর সাজিয়ে শব্দ বানান'),
        match(tw, right='meaning'),
    ],
    minutes=4,
)

# ------------------------------------------------------------------ 14: sukun

sk = [
    word('qul', 'قُلْ', 'ক্বুল', 'বলুন'),
    word('qad', 'قَدْ', 'ক্বাদ', 'নিশ্চয়ই, অবশ্যই'),
    word('lam', 'لَمْ', 'লাম', 'না (অতীতে)'),
    word('min', 'مِنْ', 'মিন', 'থেকে'),
    word('an', 'عَنْ', 'আন', 'সম্পর্কে, থেকে'),
    word('hal', 'هَلْ', 'হাল', 'কি? (প্রশ্ন)'),
    word('bal', 'بَلْ', 'বাল', 'বরং'),
    word('hum', 'هُمْ', 'হুম', 'তারা'),
]
sk2 = [word('abd', 'عَبْدُ', 'আবদু', 'বান্দা, দাস'),
       word('sabran', 'صَبْرًا', 'সাবরান', 'ধৈর্য')]
lesson(
    'সুকুন (জযম)', 'থেমে যাওয়া অক্ষর',
    ['সুকুন হলো অক্ষরের ওপরে ছোট্ট একটি গোল ( ْ )। সুকুন থাকলে অক্ষরে কোনো "আ, ই, উ" থাকে না। আওয়াজ আগের অক্ষরের সাথে লেগে থেমে যায়।',
     'যেমন: قُلْ = ক্বুল। ক্বু-এর পরে লাম থেমে গেছে। مِنْ = মিন।',
     'বাংলায় হসন্ত (্) যেমন কাজ করে, সুকুনও প্রায় তেমন।'],
    sk + sk2,
    [
        listen(sk, rounds=6),
        match(sk[:5], right='bn'),
        arrange([build_word(sk2[0]), build_word(sk[0]), build_word(sk[3])], hint='অক্ষর সাজিয়ে শব্দ বানান'),
        match([sk[0], sk[3], sk[5], sk[6], sk[7]], right='meaning'),
    ],
    minutes=4,
)

# ------------------------------------------------------------------ 15: shaddah

sh = [
    word('rabbi', 'رَبِّ', 'রাব্বি', 'রব, প্রতিপালক'),
    word('inna', 'إِنَّ', 'ইন্না', 'নিশ্চয়ই'),
    word('thumma', 'ثُمَّ', 'ছুম্মা', 'তারপর'),
    word('ummi', 'أُمِّ', 'উম্মি', 'মা'),
    word('haqq', 'حَقٌّ', 'হাক্কুন', 'সত্য'),
    word('tabbat', 'تَبَّتْ', 'তাব্বাত', 'ধ্বংস হোক'),
    word('muhammad', 'مُحَمَّدٌ', 'মুহাম্মাদুন', 'মুহাম্মদ ﷺ'),
]
lesson(
    'শাদ্দাহ (তাশদীদ)', 'একই অক্ষর দুইবার',
    ['শাদ্দাহ দেখতে ছোট্ট "w"-এর মতো ( ّ )। শাদ্দাহ থাকলে সেই অক্ষর দুইবার পড়া হয়: প্রথমবার সুকুন দিয়ে থেমে, দ্বিতীয়বার চিহ্ন দিয়ে।',
     'رَبِّ = রাব্‌-বি। ب দুইবার এসেছে। إِنَّ = ইন্‌-না।',
     'শাদ্দাহর সাথে প্রায়ই যবর, যের বা পেশও থাকে। শাদ্দাহ জোর দিয়ে বলুন, আলতো করে নয়।'],
    sh,
    [
        listen(sh, rounds=6),
        match(sh[:5], right='bn'),
        arrange([build_word(sh[0]), build_word(sh[2]), build_word(sh[5])], hint='অক্ষর সাজিয়ে শব্দ বানান'),
        match(sh[:5], right='meaning'),
    ],
    minutes=4,
)

# ------------------------------------------------------------------ 16: madd

MADD_LETTERS = [2, 3, 10, 22, 23, 24, 25, 21]
md = [syllable(n, v) for n in MADD_LETTERS for v in ('aa', 'ii', 'uu')]
mw = [
    word('qaala', 'قَالَ', 'ক্বা-লা', 'সে বলল'),
    word('qiila', 'قِيلَ', 'ক্বী-লা', 'বলা হলো'),
    word('yaquulu', 'يَقُولُ', 'ইয়াক্বূ-লু', 'সে বলে'),
    word('nuurun', 'نُورٌ', 'নূ-রুন', 'আলো'),
    word('fiihi', 'فِيهِ', 'ফী-হি', 'এর মধ্যে'),
    word('kitaab', 'كِتَـٰبٌ', 'কিতা-বুন', 'বই, কিতাব', 'খাড়া যবর'),
    word('mala', 'ٱلْمَلَـٰٓئِكَةُ', 'আল-মালা-ইকাতু', 'ফেরেশতাগণ', 'মাদ্দ চিহ্ন'),
]
lesson(
    'মাদ্দ (টেনে পড়া)', 'আলিফ, ওয়াও, ইয়া দিয়ে লম্বা আওয়াজ',
    ['তিনটি অক্ষর আগের আওয়াজ লম্বা করে: যবরের পরে আলিফ (ا), যেরের পরে ইয়া (ي), পেশের পরে ওয়াও (و)। এগুলো নিজে আলাদা আওয়াজ দেয় না।',
     'بَا = বা-আ (দুই মাত্রা টানুন), بِي = বী, بُو = বূ। এক মাত্রা মানে আঙুল একবার মোড়ার সময়।',
     'কুরআনে কখনো আলিফের বদলে অক্ষরের ওপরে ছোট্ট খাড়া দাগ থাকে ( ٰ )। একে খাড়া যবর বলে, এটাও আলিফের মতো টানতে হয়: كِتَـٰبٌ = কিতা-বুন।',
     'ঢেউয়ের মতো চিহ্ন ( ٓ ) মানে আরও বেশি টানুন, প্রায় চার-পাঁচ মাত্রা।'],
    md + mw,
    [
        listen(md, rounds=8),
        match([syllable(2, 'aa'), syllable(2, 'ii'), syllable(2, 'uu'), syllable(24, 'aa'), syllable(25, 'uu')], right='bn'),
        arrange([build_word(mw[0]), build_word(mw[3]), build_word(mw[1])], hint='অক্ষর সাজিয়ে শব্দ বানান'),
        match(mw[:5], right='meaning'),
    ],
    minutes=5,
)

# ------------------------------------------------------------------ 17: al-

al = [
    word('alhamdu', 'ٱلْحَمْدُ', 'আলহামদু', 'সব প্রশংসা', 'চাঁদের অক্ষর'),
    word('alqamar', 'ٱلْقَمَرُ', 'আল-ক্বামারু', 'চাঁদ', 'চাঁদের অক্ষর'),
    word('alard', 'ٱلْأَرْضِ', 'আল-আরদি', 'পৃথিবী, জমিন', 'চাঁদের অক্ষর'),
    word('alkitab', 'ٱلْكِتَـٰبُ', 'আল-কিতা-বু', 'কিতাবটি', 'চাঁদের অক্ষর'),
    word('ashshams', 'ٱلشَّمْسُ', 'আশ-শামসু', 'সূর্য', 'সূর্যের অক্ষর'),
    word('annas', 'ٱلنَّاسِ', 'আন-না-সি', 'মানুষ', 'সূর্যের অক্ষর'),
    word('arrahim', 'ٱلرَّحِيمِ', 'আর-রাহীম', 'পরম দয়ালু', 'সূর্যের অক্ষর'),
    word('addin', 'ٱلدِّينِ', 'আদ-দীন', 'প্রতিদান, দ্বীন', 'সূর্যের অক্ষর'),
]
lesson(
    'আল (ٱلْ): সূর্য ও চাঁদের অক্ষর', 'ل কখন পড়া হয়, কখন হয় না',
    ['অনেক শব্দের শুরুতে ٱلْ থাকে, মানে "এই নির্দিষ্ট"। শুরুতে পড়লে ٱ হয় "আ"। কিন্তু আগে অন্য শব্দ থাকলে ٱ চুপ থাকে, পড়া হয় না।',
     'চাঁদের অক্ষর: ل-এর ওপরে সুকুন থাকে, ل পড়া হয়। ٱلْقَمَرُ = আল-ক্বামারু।',
     'সূর্যের অক্ষর: ل-এ কোনো চিহ্ন থাকে না, পরের অক্ষরে শাদ্দাহ থাকে। ل চুপ থাকে: ٱلشَّمْسُ = আশ-শামসু।',
     'সহজ নিয়ম: ل-এর পরের অক্ষরে শাদ্দাহ দেখলে ل পড়বে না।'],
    al,
    [
        listen(al, rounds=6),
        quiz([
            q('ل কি পড়া হবে?', ['হ্যাঁ, চাঁদের অক্ষর', 'না, সূর্যের অক্ষর'], 1, ar=ITEMS[al[5]]['ar'], options_ar=False),
            q('ل কি পড়া হবে?', ['হ্যাঁ, চাঁদের অক্ষর', 'না, সূর্যের অক্ষর'], 0, ar=ITEMS[al[1]]['ar'], options_ar=False),
            q('ل কি পড়া হবে?', ['হ্যাঁ, চাঁদের অক্ষর', 'না, সূর্যের অক্ষর'], 1, ar=ITEMS[al[6]]['ar'], options_ar=False),
            q('ل কি পড়া হবে?', ['হ্যাঁ, চাঁদের অক্ষর', 'না, সূর্যের অক্ষর'], 0, ar=ITEMS[al[0]]['ar'], options_ar=False),
            q('কোন চিহ্ন দেখলে বুঝবে ل চুপ থাকবে?', ['পরের অক্ষরে শাদ্দাহ', 'ل-এর ওপরে সুকুন', 'পরের অক্ষরে যবর'], 0, options_ar=False),
        ]),
        match(al[:5], right='meaning'),
    ],
    minutes=4,
)

# ------------------------------------------------------------------ 18: Quran words

qw = [
    word('allah', 'ٱللَّهُ', 'আল্লাহ', 'আল্লাহ'),
    word('yawm', 'يَوْمِ', 'ইয়াওমি', 'দিন'),
    word('nar', 'نَارٌ', 'না-রুন', 'আগুন'),
    word('salam', 'سَلَـٰمٌ', 'সালা-মুন', 'শান্তি, সালাম'),
    word('hasana', 'حَسَنَةً', 'হাসানাতান', 'ভালো কাজ, কল্যাণ'),
    word('dinun', 'دِينِ', 'দীনি', 'দ্বীন, ধর্ম'),
    word('ilaha', 'إِلَـٰهَ', 'ইলা-হা', 'উপাস্য'),
    word('kana', 'كَانَ', 'কা-না', 'ছিল'),
    word('sadaqa', 'صَدَقَ', 'সাদাক্বা', 'সত্য বলেছে'),
    word('ghafara', 'غَفَرَ', 'গাফারা', 'ক্ষমা করেছে'),
    word('zalama', 'ظَلَمَ', 'যোয়ালামা', 'জুলুম করেছে'),
    word('abadan', 'أَبَدًا', 'আবাদান', 'চিরকাল'),
]
lesson(
    'কুরআনের শব্দ পড়ি', 'যা শিখেছেন, সব একসাথে',
    ['আপনি এখন সব অক্ষর আর সব চিহ্ন চেনেন। আসুন কুরআনের আসল শব্দ পড়ি!',
     'প্রতিটি শব্দ আগে নিজে বানান করে পড়ুন, যেমন: نَا · رٌ = না-রুন। তারপর চাপ দিয়ে মিলিয়ে নিন।',
     'প্রতিটি শব্দের পাশে লেখা আছে এটা কুরআনের কোন সূরার কোন আয়াতে আছে।'],
    qw,
    [
        listen(qw, rounds=8),
        match(qw[:6], right='meaning'),
        arrange([build_word(qw[2]), build_word(qw[8]), build_word(qw[9])], hint='অক্ষর সাজিয়ে কুরআনের শব্দ বানান'),
        match(qw[6:], right='bn'),
    ],
    minutes=5,
)

# ------------------------------------------------------------------ 19: qalqalah, ghunnah

qa = [
    word('yalid', 'يَلِدْ', 'ইয়ালিদ', 'জন্ম দেন', 'কলকলা'),
    word('yulad', 'يُولَدْ', 'ইউলাদ', 'জন্ম নেওয়া হয়েছে', 'কলকলা'),
    word('alfalaq', 'ٱلْفَلَقِ', 'আল-ফালাক্ব', 'ভোর', 'থামলে কলকলা'),
    word('ahad', 'أَحَدٌ', 'আহাদুন', 'এক, একক'),
]
gh = [
    word('inna', 'إِنَّ', 'ইন্না', 'নিশ্চয়ই', 'গুন্নাহ'),
    word('thumma', 'ثُمَّ', 'ছুম্মা', 'তারপর', 'গুন্নাহ'),
    word('annas', 'ٱلنَّاسِ', 'আন-না-সি', 'মানুষ', 'গুন্নাহ'),
    word('ummi', 'أُمِّ', 'উম্মি', 'মা', 'গুন্নাহ'),
]
lesson(
    'তাজবীদ: কলকলা ও গুন্নাহ', 'ق ط ب ج د · نّ مّ',
    ['কলকলা (ক্বলক্বলা): পাঁচটি অক্ষরে সুকুন থাকলে বা শব্দের শেষে থামলে আওয়াজ একটু লাফিয়ে ওঠে, যেন ছোট্ট প্রতিধ্বনি। অক্ষরগুলো: ق ط ب ج د।',
     'মনে রাখার জন্য নিজের একটা বাক্য বানান: ক্বাফ, ত্বোয়া, বা, জীম, দাল।',
     'গুন্নাহ: ن বা م-এ শাদ্দাহ থাকলে আওয়াজ নাকের ভেতর দিয়ে দুই মাত্রা ধরে রাখুন। যেমন: إِنَّ = ইন্‌-না, নাকে একটু গুনগুন।'],
    qa + gh,
    [
        listen(qa + gh, rounds=6),
        quiz([
            q('কোন অক্ষরে কলকলা হয়?', ['د', 'س', 'م', 'ل'], 0),
            q('কোন অক্ষরে কলকলা হয়?', ['ق', 'ك', 'ف', 'ن'], 0),
            q('কোন শব্দে গুন্নাহ আছে?', [ITEMS[gh[1]]['ar'], ITEMS[qa[0]]['ar'], 'قُلْ', 'هُوَ'], 0),
            q('গুন্নাহ কতক্ষণ ধরে রাখবে?', ['দুই মাত্রা', 'এক মাত্রা', 'একদম না'], 0, options_ar=False),
            q('কলকলার পাঁচ অক্ষর কোনগুলো?', ['ق ط ب ج د', 'ن م و ي ل', 'ا و ي ه ء'], 0),
        ]),
        match(qa + gh[1:2], right='meaning'),
    ],
    minutes=5,
)

# ------------------------------------------------------------------ 20: stop signs

SIGNS = [
    ('ۘ', 'ছোট মীম', 'এখানে অবশ্যই থামতে হবে। না থামলে অর্থ ভুল হতে পারে।'),
    ('ۗ', 'কলা (ق ل ى)', 'থামা ভালো, তবে চাইলে মিলিয়েও পড়া যায়।'),
    ('ۖ', 'সলা (ص ل ى)', 'মিলিয়ে পড়া ভালো, তবে চাইলে থামা যায়।'),
    ('ۚ', 'ছোট জীম', 'থামা আর মিলিয়ে পড়া দুটোই ঠিক।'),
    ('ۛ', 'তিন ফোঁটা (দুই জায়গায়)', 'পাশাপাশি দুই জায়গায় থাকে। যেকোনো একটিতে থামুন, দুটোতেই নয়।'),
    ('ۙ', 'ছোট লা', 'এখানে থামবেন না, মিলিয়ে পড়ুন।'),
]


def sign_example(mark):
    best = None
    for i, line in enumerate(LINES):
        if f' {mark} ' in line and (best is None or len(line) < len(LINES[best])):
            best = i
    return ref_of(best), LINES[best]


extra_signs = []
for mark, name, rule in SIGNS:
    r, text = sign_example(mark)
    extra_signs.append({'sign': mark, 'name': name, 'rule': rule, 'ref': r, 'example': text})
    # A mark alone has nothing to sit on; a tatweel carries it.
    add_item(f'X{ord(mark):x}', ar='ـ' + mark, bn=name, meaning=rule, kind='sign')

sign_ids = [f'X{ord(m):x}' for m, _, _ in SIGNS]
lesson(
    'থামার চিহ্ন (ওয়াক্‌ফ)', 'কোথায় থামব, কোথায় থামব না',
    ['কুরআনের লাইনের ওপরে ছোট ছোট চিহ্ন থাকে। এগুলো বলে কোথায় থামতে হবে আর কোথায় মিলিয়ে পড়তে হবে।',
     'প্রতিটি আয়াতের শেষে গোল নম্বর থাকে। সেখানে থামা সবচেয়ে ভালো।',
     'থামলে শেষ অক্ষরের যবর, যের, পেশ, তানবীন বাদ দিয়ে সুকুন দিয়ে থামুন: أَحَدٌ হয়ে যায় আহাদ। শুধু দুই যবর হলে "আ" বলে থামুন: عِلْمًا হয়ে যায় ইলমা।'],
    sign_ids,
    [
        match(sign_ids[:5], right='meaning'),
        match(sign_ids, right='bn'),
        quiz([
            q('কোন চিহ্নে অবশ্যই থামতে হবে?', ['ـۘ', 'ـۙ', 'ـۖ', 'ـۚ'], 0),
            q('কোন চিহ্নে থামা নিষেধ?', ['ـۙ', 'ـۘ', 'ـۗ', 'ـۚ'], 0),
            q('أَحَدٌ শব্দে থামলে কীভাবে পড়বে?', ['আহাদ', 'আহাদুন', 'আহাদা'], 0, options_ar=False),
            q('তিন ফোঁটার চিহ্ন (ۛ) দুই জায়গায় থাকলে কী করবে?', ['যেকোনো একটিতে থামুন', 'দুটোতেই থামুন', 'কোথাও থামবেন না'], 0, options_ar=False),
        ]),
    ],
    minutes=4,
    extra={'signs': extra_signs},
)

# ------------------------------------------------------------------ 21-22: surahs


def ayah_ref_list(s, count):
    return [f'{s}:{a}' for a in range(1, count + 1)]


def arrange_ayah(s, a):
    words = [w for w in ayah(s, a).split() if not unicodedata.combining(w[0])]
    return {'item': None, 'ref': f'{s}:{a}', 'parts': words}


lesson(
    'সূরা আল-ফাতিহা পড়ি', 'কুরআনের প্রথম সূরা, ৭ আয়াত',
    ['সূরা ফাতিহা আমরা প্রতিটি নামাজে পড়ি। এখন আপনি নিজে এটা দেখে পড়তে পারবেন!',
     'প্রতিটি আয়াতে চাপ দিলে ক্বারীর তিলাওয়াত শোনা যাবে। প্রথমে শুনুন, তারপর আঙুল রেখে রেখে নিজে পড়ুন।',
     'যা শিখেছেন মিলিয়ে নিন: কোথায় শাদ্দাহ, কোথায় মাদ্দ, কোথায় সূর্যের অক্ষর। আয়াতের শেষে থামুন।'],
    [],
    [
        {'type': 'listen_ayah', 'ayahs': ayah_ref_list(1, 7), 'rounds': 5},
        arrange([arrange_ayah(1, 2), arrange_ayah(1, 4), arrange_ayah(1, 5)], hint='শব্দ সাজিয়ে আয়াত বানান, ডান থেকে বাঁয়ে'),
        arrange([arrange_ayah(1, 6), arrange_ayah(1, 3)], hint='শব্দ সাজিয়ে আয়াত বানান'),
    ],
    minutes=5,
    ayahs=ayah_ref_list(1, 7),
)

lesson(
    'শেষ তিন সূরা', 'ইখলাস · ফালাক · নাস',
    ['কুরআনের শেষ তিনটি সূরা ছোট আর খুব প্রিয়। সকাল-সন্ধ্যায় আর ঘুমানোর আগে এগুলো পড়া হয়।',
     'সূরা ইখলাসে কলকলা খুঁজুন: يَلِدْ আর يُولَدْ। সূরা নাসে গুন্নাহ খুঁজুন: ٱلنَّاسِ।',
     'প্রথমে তিলাওয়াত শুনুন, তারপর নিজে পড়ুন। এই পাঠ শেষ হলে প্রথম স্তর শেষ!'],
    [],
    [
        {'type': 'listen_ayah', 'ayahs': ayah_ref_list(112, 4) + ayah_ref_list(113, 5) + ayah_ref_list(114, 6), 'rounds': 6},
        arrange([arrange_ayah(112, 1), arrange_ayah(112, 2), arrange_ayah(112, 4)], hint='সূরা ইখলাসের আয়াত সাজান'),
        arrange([arrange_ayah(113, 1), arrange_ayah(114, 1), arrange_ayah(114, 4)], hint='সূরা ফালাক ও নাসের আয়াত সাজান'),
    ],
    minutes=5,
    ayahs=ayah_ref_list(112, 4) + ayah_ref_list(113, 5) + ayah_ref_list(114, 6),
)

# ------------------------------------------------------------------ checks and output


def check():
    problems = []
    for l in LESSONS:
        for g in l['games']:
            ids = g.get('items', []) + g.get('pool', [])
            for i in ids:
                if i not in ITEMS:
                    problems.append(f"{l['id']}: unknown item {i}")
            if g['type'] in ('listen', 'match') and len(set(g['items'])) < 2:
                problems.append(f"{l['id']}: {g['type']} needs 2+ items")
            if g['type'] == 'match':
                right = g['right']
                vals = [ITEMS[i].get(right.split(':')[0], '') if not right.startswith('form') else 'x' for i in g['items']]
                if any(v == '' for v in vals):
                    problems.append(f"{l['id']}: match {right} missing on {g['items']}")
                if not right.startswith('form') and len(set(vals)) != len(vals):
                    problems.append(f"{l['id']}: match {right} labels repeat {vals}")
            if g['type'] == 'quiz':
                for qq in g['questions']:
                    if len(set(qq['options'])) != len(qq['options']):
                        problems.append(f"{l['id']}: quiz options repeat {qq['q']}")
            if g['type'] == 'arrange':
                for p in g['puzzles']:
                    if len(p['parts']) < 2:
                        problems.append(f"{l['id']}: arrange puzzle too short {p}")
    return problems


def main():
    problems = check()
    if MISSING:
        problems.append('not in the Tanzil text: ' + ' '.join(MISSING))
    if problems:
        print('\n'.join(problems))
        sys.exit(1)
    data = {
        'version': 1,
        'levels': [
            {'n': 1, 'title': 'পড়তে শিখি', 'subtitle': 'অক্ষর, চিহ্ন, তাজবীদের শুরু, সূরা পড়া', 'ready': True},
            {'n': 2, 'title': 'কুরআনের শব্দ', 'subtitle': 'কুরআনে সবচেয়ে বেশি আসা শব্দগুলোর অর্থ', 'ready': False},
            {'n': 3, 'title': 'সহজ ব্যাকরণ', 'subtitle': 'শব্দ কীভাবে বদলায়, বাক্য কীভাবে গড়ে', 'ready': False},
            {'n': 4, 'title': 'বুঝে পড়ি', 'subtitle': 'ছোট সূরা ও আয়াত অর্থসহ বুঝে পড়া', 'ready': False},
        ],
        'items': ITEMS,
        'lessons': LESSONS,
    }
    (ROOT / 'assets/arabic').mkdir(exist_ok=True)
    (ROOT / 'assets/arabic/level1.json').write_text(
        json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    write_audio_list()
    n_games = sum(len(l['games']) for l in LESSONS)
    print(f'{len(LESSONS)} lessons, {len(ITEMS)} items, {n_games} games, {len(AUDIO)} recordings')


SECTIONS = [
    ('name_', 'ক. অক্ষরের নাম (২৯টি)'),
    ('_a.mp3', 'খ. যবর দিয়ে (২৮টি)'),
    ('_i.mp3', 'গ. যের দিয়ে (২৮টি)'),
    ('_u.mp3', 'ঘ. পেশ দিয়ে (২৮টি)'),
    ('_an.mp3|_in.mp3|_un.mp3', 'ঙ. তানবীন'),
    ('_aa.mp3|_ii.mp3|_uu.mp3', 'চ. মাদ্দ (টেনে)'),
    ('w_', 'ছ. কুরআনের শব্দ'),
]


def section_of(f):
    for key, title in SECTIONS:
        for k in key.split('|'):
            if (k.startswith('name_') or k.startswith('w_')) and f.startswith(k):
                return title
            if not (k.startswith('name_') or k.startswith('w_')) and f.endswith(k):
                return title
    return 'অন্যান্য'


def write_audio_list():
    rows = collections.OrderedDict((t, []) for _, t in SECTIONS)
    for f, ar, bn, what in AUDIO:
        rows.setdefault(section_of(f), []).append((f, ar, bn, what))
    lines = [
        '# সহজ আরবি: রেকর্ডিং তালিকা (ক্বারী সাহেবের জন্য)',
        '',
        'প্রতিটি লাইন একটি আলাদা MP3 ফাইল। "ফাইলের নাম" ঠিক যেমন লেখা, তেমন নামে সেভ করে '
        '`assets/arabic_audio/` ফোল্ডারে রাখুন। কোনো ফাইল না থাকলে অ্যাপে সেখানে "অডিও শীঘ্রই" দেখাবে।',
        '',
        '**রেকর্ডিংয়ের নিয়ম**',
        '',
        '- প্রতিটি ফাইলে শুধু একবার, পরিষ্কার করে। আগে-পরে ০.৩ সেকেন্ডের বেশি নীরবতা নয়।',
        '- MP3, মনো, 44.1 kHz, 96–128 kbps। শান্ত ঘরে, মোবাইল হলেও চলবে।',
        '- অক্ষর যবর/যের/পেশ দিয়ে ছোট করে (এক মাত্রা), মাদ্দ দুই মাত্রা, তানবীনে শেষে ন স্পষ্ট।',
        '- কুরআনের শব্দ তাজবীদসহ, যেমন তিলাওয়াতে পড়া হয় (শেষে থামার নিয়মে)।',
        '- সূরা ফাতিহা ও শেষ তিন সূরার আয়াত রেকর্ড করতে হবে না: সেগুলো অ্যাপের বর্তমান ক্বারীর '
        '(EveryAyah.com) তিলাওয়াত থেকে বাজে।',
        '',
        f'মোট ফাইল: **{len(AUDIO)}টি**।',
        '',
    ]
    for title, rs in rows.items():
        if not rs:
            continue
        lines += [f'## {title}', '', '| # | ফাইলের নাম | আরবি | যেভাবে পড়বেন | কী |', '|---|---|---|---|---|']
        for i, (f, ar, bn, what) in enumerate(rs, 1):
            lines.append(f'| {i} | `{f}` | {ar} | {bn} | {what} |')
        lines.append('')
    (ROOT / 'docs/ARABIC_AUDIO_LIST.md').write_text('\n'.join(lines), encoding='utf-8')
    (ROOT / 'assets/arabic_audio').mkdir(exist_ok=True)
    (ROOT / 'assets/arabic_audio/README.md').write_text(
        '# সহজ আরবি audio\n\nQari recordings for the Learn Arabic lessons go here, named exactly as in '
        '`docs/ARABIC_AUDIO_LIST.md` (e.g. `name_02_ba.mp3`, `02_ba_a.mp3`, `w_khalaqa.mp3`).\n'
        'The app plays a file only when it exists here; otherwise it shows "অডিও শীঘ্রই". '
        'No synthetic (AI) voice is used for Arabic.\n', encoding='utf-8')


if __name__ == '__main__':
    main()
