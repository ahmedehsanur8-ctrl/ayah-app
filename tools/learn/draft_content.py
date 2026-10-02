#!/usr/bin/env python3
"""কুরআন বুঝি: one-time DRAFT generator for Levels 1–3 (30 lessons).

Writes the authored content that tools/learn/build_learn_db.py merges into the
content DB:
  content/lemmas_bn.csv        Bangla meaning per lemma (DRAFT)
  content/roots_bn.csv         one short Bangla idea per root (DRAFT)
  content/lessons/L*.json      30 lessons in the spec's body_json format
  content/REVIEW_SHEET.csv     for the teacher: every lemma, its Tanzil word,
                               the draft meaning and the anchor ayah
  content/REVIEW_TEXTS.csv     for the teacher: lesson explanations and root lines

Everything written here is a DRAFT (reviewed_by = "DRAFT") for internal testing.
A qualified teacher must review every meaning and explanation before release.
Meanings are short and literal; there is no tafsir or ruling.

No Arabic is typed in this file. Words are named by their place in the Quran
(surah, ayah, word) plus the corpus lemma key, and their Arabic is copied from
the Tanzil words in assets/learn/learn_content.db. Lesson JSON holds no Arabic
at all: the app looks every word up by reference.

After the teacher review the CSV/JSON files are the source of truth; this
script refuses to overwrite them unless run with --force.

Usage: python3 tools/learn/draft_content.py [--force]
"""

import argparse
import csv
import json
import pathlib
import sqlite3
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
DB = ROOT / 'assets' / 'learn' / 'learn_content.db'
CONTENT = ROOT / 'content'
DRAFT = 'DRAFT'

# --------------------------------------------------------------- meanings
# lemma_key -> (meaning_bn, translit_bn or '', note_bn or '')
M = {
    'AFFIX|PREFIX|bi+|b': ('দিয়ে, সাথে; -এ (নামে)', 'বি', 'শব্দের শুরুতে জুড়ে বসে'),
    '{som|N': ('নাম', 'ইসম', ''),
    '{ll~ah|PN': ('আল্লাহ', 'আল্লাহ', ''),
    'r~aHoma`n|N': ('পরম দয়াময়', 'আর-রহমান', ''),
    'r~aHiym|N': ('পরম দয়ালু', 'আর-রহীম', ''),
    'AFFIX|PREFIX|Al+|l': ('নির্দিষ্ট করার চিহ্ন (‘সেই’)', 'আল', 'শব্দের শুরুতে জুড়ে বসে'),
    'Hamod|N': ('প্রশংসা', 'হামদ', ''),
    'AFFIX|PREFIX|l:P+|l': ('-এর জন্য, -এর', 'লি', 'শব্দের শুরুতে জুড়ে বসে'),
    'rab~|N': ('রব, প্রতিপালক', 'রব্ব', ''),
    'Ea`lamiyn|N': ('জগৎসমূহ, সৃষ্টিজগৎ', 'আলামীন', ''),
    'ma`lik|N': ('মালিক, অধিপতি', 'মালিক', ''),
    'yawom|N': ('দিন', 'ইয়াওম', ''),
    'diyn|N': ('প্রতিদান, বিচার; দ্বীন', 'দ্বীন', ''),
    '<iy~aA|PRON': ('শুধু …কেই', 'ইয়্যা', 'ইয়্যাকা = শুধু আপনাকেই'),
    'Eabada|V': ('ইবাদত করা', 'আবাদা', ''),
    'AFFIX|PREFIX|w:CONJ+|w': ('এবং, ও', 'ওয়া', 'শব্দের শুরুতে জুড়ে বসে'),
    '{sotaEiynu|V': ('সাহায্য চাওয়া', 'ইসতা‘আনা', ''),
    'hadaY|V': ('পথ দেখানো', 'হাদা', ''),
    'AFFIX|SUFFIX|PRON:1P|nA': ('আমাদের, আমাদেরকে; আমরা', 'না', 'শব্দের শেষে জুড়ে বসে'),
    'Sira`T|N': ('পথ', 'সিরাত', ''),
    'm~usotaqiym|N': ('সরল, সোজা', 'মুসতাকীম', ''),
    '{l~a*iY|REL': ('যে, যারা', 'আল্লাযী', ''),
    '>anoEama|V': ('অনুগ্রহ করা', 'আন‘আমা', ''),
    'EalaY`|P': ('উপর, প্রতি', '‘আলা', ''),
    'gayor|N': ('ছাড়া, নয়; ভিন্ন', 'গাইর', ''),
    'magoDuwb|N': ('যার উপর ক্রোধ হয়েছে', 'মাগদূব', ''),
    'laA|NEG': ('না', 'লা', ''),
    'DaA^l~|N': ('পথভ্রষ্ট', 'দোয়াল্লীন', ''),
    '>akobar|N': ('সবচেয়ে বড়, অনেক বড়', 'আকবার', ''),
    'suboHa`n|N': ('পবিত্রতা', 'সুবহান', 'সুবহানা = পবিত্র …'),
    'EaZiym|N': ('মহান', 'আযীম', ''),
    '>aEolaY`|N': ('সর্বোচ্চ', 'আ‘লা', ''),
    'sab~aHa|V': ('পবিত্রতা ঘোষণা করা', 'সাব্বাহা', ''),
    'qaAla|V': ('বলা', 'কালা', ''),
    'PRON|3MS|hw': ('সে, তিনি', 'হুওয়া', ''),
    '>aHad|N': ('এক, একক; কেউ', 'আহাদ', ''),
    'S~amad|N': ('অমুখাপেক্ষী', 'সামাদ', ''),
    'lam|NEG': ('না (অতীতে: করেনি)', 'লাম', ''),
    'walada|V': ('জন্ম দেওয়া', 'ওয়ালাদা', ''),
    'kufuw|N': ('সমকক্ষ, সমতুল্য', 'কুফুওয়ান', ''),
    'EaSor|N': ('সময়, যুগ', '‘আসর', ''),
    '<in~|ACC': ('নিশ্চয়ই', 'ইন্না', ''),
    '<insa`n|N': ('মানুষ', 'ইনসান', ''),
    'xusor|N': ('ক্ষতি', 'খুসর', ''),
    '<il~aA|EXP': ('তবে, ছাড়া', 'ইল্লা', ''),
    "'aAmana|V": ('ঈমান আনা, বিশ্বাস করা', 'আমানা', ''),
    'Eamila|V': ('কাজ করা', '‘আমিলা', ''),
    'S~a`liHa`t|N': ('সৎকাজসমূহ', 'সালিহাত', ''),
    'Haq~|N': ('সত্য', 'হাক্ক', ''),
    'Sabor|N': ('ধৈর্য', 'সবর', ''),
    # Level 2
    'min|P': ('থেকে', '', ''),
    'fiY|P': ('মধ্যে, -তে', '', ''),
    '<ilaY`|P': ('দিকে, প্রতি', '', ''),
    'Ean|P': ('থেকে; সম্পর্কে', '', ''),
    'PRON|3FS|hY': ('সে (নারী); এটি', '', ''),
    'PRON|3MP|hm': ('তারা', '', ''),
    'PRON|2MS|nt': ('তুমি, আপনি (একজন পুরুষ)', '', ''),
    'PRON|2MP|ntm': ('তোমরা, আপনারা', '', ''),
    'PRON|1S|nA': ('আমি', '', ''),
    'PRON|1P|nHn': ('আমরা', '', ''),
    'AFFIX|SUFFIX|PRON:3MS|h': ('তার, তাকে', '', 'শব্দের শেষে জুড়ে বসে'),
    'AFFIX|SUFFIX|PRON:3MP|hm': ('তাদের, তাদেরকে', '', 'শব্দের শেষে জুড়ে বসে'),
    'AFFIX|SUFFIX|PRON:2MS|k': ('তোমার, তোমাকে', '', 'শব্দের শেষে জুড়ে বসে'),
    'AFFIX|SUFFIX|PRON:2MP|km': ('তোমাদের, তোমাদেরকে', '', 'শব্দের শেষে জুড়ে বসে'),
    'AFFIX|SUFFIX|PRON:1S|Y': ('আমার', '', 'শব্দের শেষে জুড়ে বসে'),
    'ha`*aA|DEM': ('এটা, এই', '', 'নারীবাচক রূপও এই শব্দের'),
    '*a`lik|DEM': ('ওটা, ঐ', '', 'নারীবাচক রূপও এই শব্দের'),
    '>uwla`^}ik|DEM': ('ওরা, ঐসব', '', ''),
    'kita`b|N': ('কিতাব, বই', '', ''),
    'hudFY|N': ('পথনির্দেশ, হিদায়াত', '', ''),
    'mut~aqiyn|N': ('মুত্তাকি, আল্লাহভীরু', '', ''),
    'rayob|N': ('সন্দেহ', '', ''),
    'man|INTG': ('কে?', '', ''),
    'maA|INTG': ('কী?', '', ''),
    'maA*aA|INTG': ('কী?', '', ''),
    'kayof|INTG': ('কীভাবে?', '', ''),
    'hal|INTG': ('কি? (হ্যাঁ/না প্রশ্ন)', '', ''),
    'maA|NEG': ('না', '', ''),
    'lan|NEG': ('কখনো না (ভবিষ্যতে)', '', ''),
    'l~ayosa|V': ('নয়', '', ''),
    '>an~|ACC': ('যে (নিশ্চয়ই যে)', '', ''),
    'qad|CERT': ('অবশ্যই, ইতিমধ্যে', '', ''),
    'kul~|N': ('সব, প্রত্যেক', '', ''),
    "$aYo'|N": ('জিনিস, বস্তু', '', ''),
    'qadiyr|N': ('ক্ষমতাবান', '', ''),
    'Ealiym|N': ('সর্বজ্ঞ', '', ''),
    'Hakiym|N': ('প্রজ্ঞাময়', '', ''),
    'gafuwr|N': ('ক্ষমাশীল', '', ''),
    'samiyE|N': ('সর্বশ্রোতা', '', ''),
    'baSiyr|N': ('সর্বদ্রষ্টা', '', ''),
    '>aqaAma|V': ('কায়েম করা, প্রতিষ্ঠা করা', '', ''),
    'Salaw`p|N': ('সালাত, নামাজ', '', ''),
    'razaqa|V': ('রিজিক দেওয়া', '', ''),
    '>anfaqa|V': ('খরচ করা', '', ''),
    # Level 3
    'kaAna|V': ('ছিল; হওয়া', '', ''),
    'jaEala|V': ('বানানো, করা', '', ''),
    'xalaqa|V': ('সৃষ্টি করা', '', ''),
    'AFFIX|SUFFIX|PRON:3MP|wA': ('তারা (অতীতে করল)', '', 'অতীত ক্রিয়ার শেষে'),
    'AFFIX|SUFFIX|PRON:2MS|t': ('তুমি (অতীতে করলে)', '', 'অতীত ক্রিয়ার শেষে'),
    'AFFIX|SUFFIX|PRON:1S|t': ('আমি (অতীতে করলাম)', '', 'অতীত ক্রিয়ার শেষে'),
    'Ealima|V': ('জানা', '', ''),
    'AFFIX|SUFFIX|PRON:3MP|wn': ('তারা (করে)', '', 'বর্তমান ক্রিয়ার শেষে'),
    '{t~aqaY`|V': ('তাকওয়া অবলম্বন করা', '', ''),
    'daEaA|V': ('ডাকা, দোয়া করা', '', ''),
    'AFFIX|PREFIX|ya+|y': ('হে (ডাকার শব্দ)', '', 'শব্দের শুরুতে জুড়ে বসে'),
    '>ay~uhaA|N': ('ডাকার সাথে বসে (হে …)', '', ''),
    'AFFIX|SUFFIX|PRON:2MP|wA': ('তোমরা (আদেশ: করো)', '', 'আদেশ ক্রিয়ার শেষে'),
    'kafara|V': ('অস্বীকার করা, কুফরি করা', '', ''),
    'jan~ap|N': ('জান্নাত; বাগান', '', ''),
    'naAr|N': ('আগুন', '', ''),
    '>ajor|N': ('প্রতিদান, পুরস্কার', '', ''),
    'Eilom|N': ('জ্ঞান', '', ''),
    '>aEolam|N': ('বেশি জানেন', '', ''),
    'Eal~ama|V': ('শিক্ষা দেওয়া', '', ''),
    'kataba|V': ('লেখা; নির্ধারণ করা', '', ''),
    'SiyaAm|N': ('রোজা, সিয়াম', '', ''),
    'laEal~|ACC': ('যাতে, হয়তো', '', ''),
    'n~aAs|N': ('মানুষ, লোকেরা', '', ''),
    '>aroD|N': ('পৃথিবী, জমিন', '', ''),
    "samaA^'|N": ('আকাশ', '', 'বহুবচন: আকাশমণ্ডলী'),
    'qawom|N': ('জাতি, সম্প্রদায়', '', ''),
    'd~unoyaA|N': ('দুনিয়া', '', ''),
    'A^xir|N': ('শেষ; আখিরাত', '', ''),
    'qabol|N': ('আগে', '', ''),
    'baEod|N': ('পরে', '', ''),
    'yawoma}i*|T': ('সেদিন', '', ''),
    'Hay~|N': ('চিরঞ্জীব', '', ''),
    'qay~uwm|N': ('চিরস্থায়ী ধারক', '', ''),
    'nawom|N': ('ঘুম', '', ''),
    '<ila`h|N': ('ইলাহ, উপাস্য', '', ''),
}

# Root (as the DB stores it, letters spaced) is matched by its Bangla idea, typed
# here in Bangla only. The Arabic letters are never typed: the script reads them
# from the DB and checks every lesson root has a line.
ROOT_IDEAS = {
    # keyed by the Buckwalter root of a lemma we teach (from the corpus)
    'smw': 'নাম; উঁচু হওয়া', 'Alh': 'উপাস্য', 'rHm': 'দয়া', 'Hmd': 'প্রশংসা',
    'rbb': 'প্রতিপালন', 'Elm': 'জানা', 'mlk': 'মালিকানা, রাজত্ব', 'ywm': 'দিন',
    'dyn': 'প্রতিদান, আনুগত্য', 'Ebd': 'দাসত্ব, ইবাদত', 'Ewn': 'সাহায্য',
    'hdy': 'পথ দেখানো', 'SrT': 'পথ', 'qwm': 'দাঁড়ানো, ঠিক থাকা', 'nEm': 'অনুগ্রহ',
    'gyr': 'ভিন্নতা', 'gDb': 'রাগ', 'Dll': 'পথ হারানো', 'kbr': 'বড় হওয়া',
    'sbH': 'পবিত্রতা ঘোষণা', 'EZm': 'মহত্ত্ব', 'Elw': 'উঁচু হওয়া', 'qwl': 'বলা',
    'AHd': 'এক হওয়া', 'Smd': 'অমুখাপেক্ষিতা', 'wld': 'জন্ম', 'kfA': 'সমান হওয়া',
    'ESr': 'সময়', 'Ans': 'মানুষ', 'xsr': 'ক্ষতি', 'Amn': 'নিরাপত্তা, বিশ্বাস',
    'Eml': 'কাজ', 'SlH': 'ভালো হওয়া', 'Hqq': 'সত্য', 'Sbr': 'ধৈর্য', 'ktb': 'লেখা',
    'wqy': 'রক্ষা পাওয়া', 'ryb': 'সন্দেহ', 'kll': 'সমগ্রতা', '$yA': 'ইচ্ছা, জিনিস',
    'qdr': 'ক্ষমতা, পরিমাপ', 'Hkm': 'প্রজ্ঞা, বিচার', 'gfr': 'ক্ষমা', 'smE': 'শোনা',
    'bSr': 'দেখা', 'Slw': 'সালাত, দোয়া', 'rzq': 'রিজিক', 'nfq': 'খরচ',
    'kwn': 'হওয়া', 'jEl': 'বানানো', 'xlq': 'সৃষ্টি', 'dEw': 'ডাকা',
    'kfr': 'অস্বীকার, ঢেকে রাখা', 'jnn': 'ঢেকে থাকা', 'nwr': 'আলো, আগুন',
    'Ajr': 'প্রতিদান', 'Swm': 'রোজা, বিরত থাকা', 'nws': 'মানুষ', 'ArD': 'পৃথিবী',
    'dnw': 'কাছে হওয়া', 'Axr': 'পরে হওয়া, শেষ', 'qbl': 'সামনে, আগে',
    'bEd': 'পরে হওয়া', 'Hyy': 'জীবন', 'nwm': 'ঘুম', 'lys': 'না হওয়া',
    'kyf': 'অবস্থা', 'xlf': 'পেছনে', 'nzl': 'নামা', 'Eqd': '',
}

# --------------------------------------------------------------- lessons
# words: (surah, ayah, word, lemma_key) — the lemma is checked against that word.
L = []


def lesson(id_, level, title, objective, minutes, anchor, words, explain, example,
           more=None, order=None, split=(), listen=(), checkpoint=False, recall_from=None,
           word_to=None):
    L.append(dict(id=id_, level=level, title=title, objective=objective, minutes=minutes,
                  anchor=anchor, words=words, explain=explain, example=example,
                  more=more or [], order=order, split=list(split), listen=list(listen),
                  checkpoint=checkpoint, recall_from=recall_from, word_to=word_to))


lesson('L1-01', 1, 'বিসমিল্লাহর অর্থ', 'বিসমিল্লাহর প্রতিটি শব্দ বুঝি', 8, (1, 1, 1), [
    (1, 1, 1, 'AFFIX|PREFIX|bi+|b'), (1, 1, 1, '{som|N'), (1, 1, 2, '{ll~ah|PN'),
    (1, 1, 3, 'r~aHoma`n|N'), (1, 1, 4, 'r~aHiym|N')],
    'প্রথম শব্দটি দুই ভাগে গড়া: শুরুর ছোট অংশ ‘বি’ মানে ‘দিয়ে’ বা ‘নামে’, আর বাকি অংশ মানে ‘নাম’। '
    'তাই প্রথম দুই শব্দ একসাথে: ‘আল্লাহর নামে’।', (1, 1, 1), order=(1, 1), split=[(1, 1, 1)])
lesson('L1-02', 1, 'সব প্রশংসা আল্লাহর', 'আয়াত ১:২ নিজে পড়ে বুঝি', 8, (1, 2, 2), [
    (1, 2, 1, 'AFFIX|PREFIX|Al+|l'), (1, 2, 1, 'Hamod|N'), (1, 2, 2, 'AFFIX|PREFIX|l:P+|l'),
    (1, 2, 3, 'rab~|N'), (1, 2, 4, 'Ea`lamiyn|N')],
    'অনেক আরবি শব্দের শুরুতে ‘আল’ থাকে। এটি শব্দটিকে নির্দিষ্ট করে, যেমন বাংলায় ‘টি/টা’: '
    'হামদ = প্রশংসা, আল-হামদ = সেই প্রশংসা। শুরুতে ‘লি’ মানে ‘-এর জন্য’: লিল্লাহ = আল্লাহর জন্য।',
    (1, 2, 1), order=(1, 2), split=[(1, 2, 2), (1, 2, 1)])
lesson('L1-03', 1, 'বিচার দিনের মালিক', 'পাশাপাশি দুই বিশেষ্য = ‘-এর’', 8, (1, 4, 4), [
    (1, 4, 1, 'ma`lik|N'), (1, 4, 2, 'yawom|N'), (1, 4, 3, 'diyn|N')],
    'দুটি বিশেষ্য পাশাপাশি বসলে মাঝে ‘-এর’ অর্থ আসে: মালিকি ইয়াওমিদ্দীন = বিচার দিনের মালিক। '
    'আরবিতে ‘-এর’ আলাদা করে লেখা হয় না, পাশাপাশি বসাই যথেষ্ট।', (1, 4, 2), order=(1, 4))
lesson('L1-04', 1, 'শুধু আপনারই ইবাদত', 'ক্রিয়ার ভেতরে ‘আমরা’', 10, (1, 5, 5), [
    (1, 5, 1, '<iy~aA|PRON'), (1, 5, 2, 'Eabada|V'), (1, 5, 3, 'AFFIX|PREFIX|w:CONJ+|w'),
    (1, 5, 4, '{sotaEiynu|V')],
    'ক্রিয়ার শুরুতে ‘ন’ থাকলে কাজটি ‘আমরা’ করি: না‘বুদু = আমরা ইবাদত করি, '
    'নাসতা‘ঈন = আমরা সাহায্য চাই। শুরুর ‘ওয়া’ মানে ‘এবং’।', (1, 5, 2), order=(1, 5),
    split=[(1, 5, 3)])
lesson('L1-05', 1, 'সরল পথ দেখান', 'বিশেষণ বসে বিশেষ্যের পরে', 10, (1, 6, 6), [
    (1, 6, 1, 'hadaY|V'), (1, 6, 1, 'AFFIX|SUFFIX|PRON:1P|nA'), (1, 6, 2, 'Sira`T|N'),
    (1, 6, 3, 'm~usotaqiym|N')],
    'বিশেষণ বসে বিশেষ্যের পরে, আর দুটোতেই ‘আল’ থাকে: আস-সিরাতাল মুসতাকীম = সরল পথ। '
    'শব্দের শেষে ‘না’ মানে ‘আমাদের/আমাদেরকে’: ইহদিনা = আমাদেরকে পথ দেখান।', (1, 6, 3),
    order=(1, 6), split=[(1, 6, 1)])
lesson('L1-06', 1, 'যাদের প্রতি অনুগ্রহ', '‘যারা’ শব্দটি চিনি', 10, (1, 7, 7), [
    (1, 7, 2, '{l~a*iY|REL'), (1, 7, 3, '>anoEama|V'), (1, 7, 4, 'EalaY`|P'),
    (1, 7, 5, 'gayor|N'), (1, 7, 6, 'magoDuwb|N'), (1, 7, 8, 'laA|NEG'),
    (1, 7, 9, 'DaA^l~|N')],
    '‘আল্লাযীনা’ মানে ‘যারা’; এর পরে তাদের কথা আসে। ‘আলাইহিম’ শব্দে ‘আলা’ (প্রতি) আর '
    'শেষের ‘হিম’ (তাদের) মিলে হয় ‘তাদের প্রতি’।', (1, 7, 4), split=[(1, 7, 8)])
lesson('L1-07', 1, 'পুরো ফাতিহা বুঝি', 'অনুবাদ ছাড়া সূরা ফাতিহা বুঝি', 10, (1, 1, 7), [],
    'এখন পুরো সূরা ফাতিহার প্রায় সব শব্দ আপনি চেনেন। অনুবাদ না দেখে প্রতিটি আয়াত পড়ুন; '
    'যে শব্দ মনে পড়ছে না, শুধু সেটিতে চাপ দিন।', (1, 2, 3), recall_from=['L1-01', 'L1-06'])
lesson('L1-08', 1, 'সালাতের শব্দ', 'তাকবীর ও তাসবীহের শব্দ চিনি', 10, (87, 1, 1), [
    (2, 217, 22, '>akobar|N'), (2, 32, 2, 'suboHa`n|N'), (2, 255, 50, 'EaZiym|N'),
    (87, 1, 4, '>aEolaY`|N'), (87, 1, 1, 'sab~aHa|V')],
    'সালাতে আমরা যে শব্দগুলো বারবার বলি, সেগুলো কুরআনেও আছে। ‘আকবার’ ও ‘আ‘লা’ ধরনের শব্দ '
    '‘সবচেয়ে বেশি’ বোঝায়: আকবার = সবচেয়ে বড়, আল-আ‘লা = সর্বোচ্চ।', (87, 1, 4),
    order=(87, 1), listen=['>aEolaY`|N', 'sab~aHa|V'])
lesson('L1-09', 1, 'সূরা ইখলাস', 'সূরা ইখলাস বুঝি', 10, (112, 1, 4), [
    (112, 1, 1, 'qaAla|V'), (112, 1, 2, 'PRON|3MS|hw'), (112, 1, 4, '>aHad|N'),
    (112, 2, 2, 'S~amad|N'), (112, 3, 1, 'lam|NEG'), (112, 3, 2, 'walada|V'),
    (112, 4, 4, 'kufuw|N')],
    '‘কুল’ একটি আদেশ: ‘বলুন’। ‘লাম’ + ক্রিয়া মানে কাজটি হয়নি: লাম ইয়ালিদ = তিনি জন্ম দেননি, '
    'ওয়া লাম ইউলাদ = এবং তাঁকেও জন্ম দেওয়া হয়নি।', (112, 1, 1), order=(112, 3),
    split=[(112, 3, 3)])
lesson('L1-10', 1, 'সূরা আসর', 'সূরা আসর বুঝি; প্রথম স্তরের পরীক্ষা', 12, (103, 1, 3), [
    (103, 1, 1, 'EaSor|N'), (103, 2, 1, '<in~|ACC'), (103, 2, 2, '<insa`n|N'),
    (103, 2, 4, 'xusor|N'), (103, 3, 1, '<il~aA|EXP'), (103, 3, 3, "'aAmana|V"),
    (103, 3, 4, 'Eamila|V'), (103, 3, 5, 'S~a`liHa`t|N'), (103, 3, 7, 'Haq~|N'),
    (103, 3, 9, 'Sabor|N')],
    '‘ইন্না’ মানে ‘নিশ্চয়ই’; বাক্যের শুরুতে বসে কথাকে জোর দেয়। ‘ইল্লা’ মানে ‘তবে/ছাড়া’। '
    'শেষ আয়াতে ‘বিল-হাক্ক’ ও ‘বিস-সবর’ শব্দে শুরুর ‘বি’ আর ‘আল’ আপনি আগেই চেনেন।',
    (103, 2, 1), split=[(103, 3, 7), (103, 3, 9)], listen=['<insa`n|N'], checkpoint=True)

lesson('L2-11', 2, 'কোথা থেকে, কোথায়', 'মূল অব্যয়গুলো চিনি', 10, (2, 4, 4), [
    (2, 4, 8, 'min|P'), (2, 2, 5, 'fiY|P'), (2, 4, 5, '<ilaY`|P'), (2, 36, 3, 'Ean|P')],
    'মিন, ফী, ইলা, ‘আন, ‘আলা — এগুলো অব্যয় (হারফে জার)। এরা বিশেষ্যের আগে বসে, আর সেই '
    'বিশেষ্যের শেষে সাধারণত ‘ই’-কার আওয়াজ আসে: মিন কাবলিকা = আপনার আগে থেকে।', (2, 4, 8))
lesson('L2-12', 2, 'সে, তারা, তুমি', 'আলাদা সর্বনাম চিনি', 10, (2, 5, 5), [
    (2, 68, 8, 'PRON|3FS|hY'), (2, 5, 7, 'PRON|3MP|hm'), (2, 32, 10, 'PRON|2MS|nt'),
    (2, 22, 22, 'PRON|2MP|ntm'), (2, 160, 9, 'PRON|1S|nA'), (2, 11, 10, 'PRON|1P|nHn')],
    'আলাদা সর্বনামগুলো: হুওয়া (সে), হিয়া (সে, নারী), হুম (তারা), আনতা (তুমি), '
    'আনতুম (তোমরা), আনা (আমি), নাহনু (আমরা)। হুওয়া আপনি সূরা ইখলাসে শিখেছেন।', (2, 5, 7))
lesson('L2-13', 2, 'আপনার রব, তাদের রব', 'শব্দের শেষে জোড়া সর্বনাম', 12, (2, 21, 21), [
    (2, 2, 5, 'AFFIX|SUFFIX|PRON:3MS|h'), (2, 5, 5, 'AFFIX|SUFFIX|PRON:3MP|hm'),
    (2, 30, 3, 'AFFIX|SUFFIX|PRON:2MS|k'), (2, 21, 4, 'AFFIX|SUFFIX|PRON:2MP|km'),
    (2, 30, 5, 'AFFIX|SUFFIX|PRON:1S|Y')],
    'সর্বনাম শব্দের শেষে জুড়েও বসে, তখন মানে হয় ‘-এর’ বা ‘-কে’: রব্বুকা = তোমার রব, '
    'রব্বাকুম = তোমাদের রব, রব্বিহিম = তাদের রব। শেষের ‘-ঈ’ মানে ‘আমার’।', (2, 21, 4),
    more=[(2, 5, 5), (2, 30, 3)], split=[(2, 21, 4), (2, 5, 5), (2, 30, 3)])
lesson('L2-14', 2, 'এটা, ওটা', 'কাছের ও দূরের ইঙ্গিত', 10, (2, 2, 2), [
    (2, 25, 20, 'ha`*aA|DEM'), (2, 2, 1, '*a`lik|DEM'), (2, 5, 1, '>uwla`^}ik|DEM')],
    'কাছের জিনিসের জন্য ‘হাযা’ (এটা; নারীবাচকে ‘হাযিহি’), দূরের জন্য ‘যালিকা’ '
    '(ওটা; নারীবাচকে ‘তিলকা’)। অনেকের জন্য ‘উলাইকা’ = ওরা।', (2, 2, 1),
    more=[(2, 35, 14), (2, 111, 11)])
lesson('L2-15', 2, 'ছোট বাক্য: ‘ওটা কিতাব’', '‘হয়’ ছাড়া বাক্য', 12, (2, 2, 2), [
    (2, 2, 2, 'kita`b|N'), (2, 2, 6, 'hudFY|N'), (2, 2, 7, 'mut~aqiyn|N'),
    (2, 2, 4, 'rayob|N')],
    'আরবিতে ‘হয়/আছে’ শব্দ ছাড়াই বাক্য হয়: প্রথমে যার কথা (মুবতাদা), পরে তার সম্পর্কে খবর '
    '(খবর)। যালিকাল কিতাব = ওটা সেই কিতাব; হুদাল লিল মুত্তাকীন = মুত্তাকিদের জন্য পথনির্দেশ।',
    (2, 2, 2), order=(2, 2), split=[(2, 2, 7)])
lesson('L2-16', 2, 'প্রশ্নের শব্দ', 'প্রশ্ন চিনি', 10, (88, 1, 1), [
    (2, 255, 20, 'man|INTG'), (101, 3, 1, 'maA|INTG'), (2, 26, 24, 'maA*aA|INTG'),
    (2, 28, 1, 'kayof|INTG'), (88, 1, 1, 'hal|INTG')],
    'প্রশ্নের শব্দ বাক্যের শুরুতে বসে: মান (কে), মা বা মাযা (কী), কাইফা (কীভাবে), '
    'হাল (কি — হ্যাঁ/না প্রশ্ন)।', (88, 1, 1), more=[(101, 3, 3)], order=(88, 1))
lesson('L2-17', 2, 'না, কখনো না', 'কোন ‘না’ কোন সময়ের', 12, (112, 3, 3), [
    (2, 8, 9, 'maA|NEG'), (2, 24, 4, 'lan|NEG'), (2, 198, 1, 'l~ayosa|V')],
    '‘লা’ সাধারণ ‘না’; ‘লাম’ অতীতে ‘করেনি’; ‘লান’ ভবিষ্যতে ‘কখনো করবে না’; ‘লাইসা’ মানে '
    '‘নয়’; ‘মা’ও কখনো ‘না’ বোঝায়। লা ও লাম আপনি আগেই শিখেছেন।', (112, 3, 1),
    more=[(2, 2, 3)])
lesson('L2-18', 2, 'নিশ্চয়ই আল্লাহ সক্ষম', 'জোর দেওয়ার শব্দ', 12, (2, 20, 20), [
    (2, 25, 6, '>an~|ACC'), (2, 144, 1, 'qad|CERT'), (2, 20, 23, 'kul~|N'),
    (2, 20, 24, "$aYo'|N"), (2, 20, 25, 'qadiyr|N')],
    '‘ইন্না’ ও ‘আন্না’ কথাকে জোর দেয়। ‘কাদ’ অতীত ক্রিয়ার আগে মানে ‘অবশ্যই/ইতিমধ্যে’। '
    'ইন্নাল্লাহা ‘আলা কুল্লি শাইয়িন কাদীর = নিশ্চয়ই আল্লাহ সব কিছুর উপর ক্ষমতাবান।',
    (2, 20, 20))
lesson('L2-19', 2, 'আল্লাহর গুণ', 'গুণবাচক শব্দের ছাঁচ', 12, (2, 173, 24), [
    (2, 29, 19, 'Ealiym|N'), (2, 32, 12, 'Hakiym|N'), (2, 173, 24, 'gafuwr|N'),
    (2, 127, 13, 'samiyE|N'), (2, 96, 23, 'baSiyr|N')],
    'আল্লাহর অনেক গুণবাচক শব্দের একই ছাঁচ: ‘ফা‘ঈল’ (‘আলীম, হাকীম, সামী‘, বাসীর) '
    'আর ‘ফা‘ঊল’ (গাফূর)। ছাঁচটি চিনলে নতুন শব্দও সহজে চেনা যায়।', (2, 173, 24))
lesson('L2-20', 2, 'আয়াত ২:২–২:৫', 'চার আয়াত পড়ি; দ্বিতীয় স্তরের পরীক্ষা', 15, (2, 2, 5), [
    (2, 3, 4, '>aqaAma|V'), (2, 3, 5, 'Salaw`p|N'), (2, 3, 7, 'razaqa|V'),
    (2, 3, 8, '>anfaqa|V')],
    'আয়াত ২:২ থেকে ২:৫ পর্যন্ত পড়ুন। নতুন শব্দগুলো: ইউকীমূন (কায়েম করে), আস-সালাত, '
    'রাযাকনা (আমরা রিজিক দিয়েছি), ইউনফিকূন (খরচ করে)।', (2, 3, 4),
    checkpoint=True)

lesson('L3-21', 3, 'সে করল', 'অতীত ক্রিয়া', 12, (96, 2, 2), [
    (2, 75, 6, 'kaAna|V'), (2, 22, 2, 'jaEala|V'), (96, 2, 1, 'xalaqa|V')],
    'আরবি ক্রিয়ার তিন রূপ: অতীত, বর্তমান/ভবিষ্যৎ, আর আদেশ। অতীতের মূল রূপ মানে ‘সে করল’: '
    'খালাকা = তিনি সৃষ্টি করলেন, কালা = সে বলল, কানা = ছিল।', (96, 2, 1), order=(96, 2))
lesson('L3-22', 3, 'কে করল?', 'অতীত ক্রিয়ার শেষ অংশ', 12, (2, 11, 11), [
    (2, 11, 8, 'AFFIX|SUFFIX|PRON:3MP|wA'), (1, 7, 3, 'AFFIX|SUFFIX|PRON:2MS|t'),
    (2, 40, 6, 'AFFIX|SUFFIX|PRON:1S|t')],
    'অতীত ক্রিয়ার শেষ অংশ বলে কে কাজটি করল: কালূ = তারা বলল, আন‘আমতা = আপনি অনুগ্রহ করলেন, '
    'রাযাকনা = আমরা দিলাম। শেষের ‘তু’ মানে ‘আমি’।', (2, 11, 8),
    split=[(2, 11, 8), (1, 7, 3)])
lesson('L3-23', 3, 'সে করে / করবে', 'বর্তমান ক্রিয়া', 12, (2, 3, 3), [
    (2, 13, 19, 'Ealima|V'), (2, 3, 2, 'AFFIX|SUFFIX|PRON:3MP|wn')],
    'বর্তমান ক্রিয়ার শুরুর অক্ষর বলে কে করে: ইয়া (সে), তা (তুমি), না (আমরা), আ (আমি)। '
    'শেষে ‘-ঊনা’ থাকলে ‘তারা করে’: ইউ’মিনূনা = তারা ঈমান আনে।', (2, 3, 2),
    split=[(2, 3, 2), (2, 3, 8)])
lesson('L3-24', 3, 'আদেশ', 'আদেশ রূপ চিনি', 12, (2, 21, 21), [
    (2, 21, 11, '{t~aqaY`|V'), (2, 23, 13, 'daEaA|V'), (2, 21, 1, 'AFFIX|PREFIX|ya+|y'),
    (2, 21, 1, '>ay~uhaA|N'), (2, 21, 3, 'AFFIX|SUFFIX|PRON:2MP|wA')],
    'আদেশ রূপ ‘করো’ বোঝায়: উ‘বুদূ = তোমরা ইবাদত করো। ডাকার শব্দ ‘ইয়া আইয়ুহা’ = হে …! '
    'ইয়া আইয়ুহান নাস = হে মানুষ!', (2, 21, 3), split=[(2, 21, 3), (2, 21, 1)])
lesson('L3-25', 3, 'ঈমান ও আমল', 'জোড়ায় শব্দ শিখি', 12, (2, 25, 34), [
    (2, 102, 9, 'kafara|V'), (2, 25, 8, 'jan~ap|N'), (2, 24, 7, 'naAr|N'),
    (2, 62, 16, '>ajor|N')],
    'কিছু শব্দ জোড়ায় শিখলে সহজ: আমানা (ঈমান আনা) — কাফারা (অস্বীকার করা); '
    'জান্নাত — নার (আগুন)।', (2, 25, 8))
lesson('L3-26', 3, 'জ্ঞানের শব্দ', 'এক মূল, অনেক শব্দ', 12, (96, 5, 5), [
    (2, 255, 37, 'Eilom|N'), (2, 140, 15, '>aEolam|N'), (96, 5, 1, 'Eal~ama|V')],
    'একই মূল অক্ষর থেকে অনেক শব্দ হয়। ‘আইন-লাম-মীম’ থেকে: ‘আলিমা (জানল), ‘ইলম (জ্ঞান), '
    '‘আল্লামা (শেখাল), আ‘লাম (বেশি জানেন), ‘আলীম (সর্বজ্ঞ)।', (96, 5, 1), order=(96, 5))
lesson('L3-27', 3, 'মূল অক্ষর চিনি', 'তিন অক্ষরের মূল', 12, (2, 183, 14), [
    (2, 183, 4, 'kataba|V'), (2, 183, 6, 'SiyaAm|N'), (2, 183, 13, 'laEal~|ACC')],
    'প্রায় সব আরবি শব্দের পেছনে তিনটি মূল অক্ষর থাকে। কাফ-তা-বা থেকে: কাতাবা (লিখল), '
    'কিতাব (বই), কুতিবা (লেখা হয়েছে, নির্ধারণ করা হয়েছে)।', (2, 183, 4), more=[(2, 2, 2)])
lesson('L3-28', 3, 'মানুষ, আকাশ, পৃথিবী', 'সৃষ্টির শব্দ', 12, (2, 22, 23), [
    (2, 21, 2, 'n~aAs|N'), (2, 22, 4, '>aroD|N'), (2, 22, 6, "samaA^'|N"),
    (2, 54, 4, 'qawom|N')],
    'আরবিতে বহুবচন অনেক সময় শব্দের গঠন বদলে হয়: সামা’ (আকাশ) থেকে সামাওয়াত '
    '(আকাশমণ্ডলী)।', (2, 22, 6), more=[(2, 255, 16)], split=[(2, 22, 6)])
lesson('L3-29', 3, 'দুনিয়া ও আখিরাত', 'সময়ের শব্দ', 12, (2, 4, 12), [
    (2, 85, 38, 'd~unoyaA|N'), (2, 4, 10, 'A^xir|N'), (2, 4, 9, 'qabol|N'),
    (2, 27, 6, 'baEod|N'), (99, 4, 1, 'yawoma}i*|T')],
    'সময়ের শব্দ: কাবল (আগে), বা‘দ (পরে), দুনিয়া, আখিরাহ, ইয়াওমাইযিন (সেদিন)।',
    (2, 4, 9), split=[(2, 25, 4)])
lesson('L3-30', 3, 'আয়াতুল কুরসি (প্রথম অংশ)', 'তিন স্তরের সব শেখা কাজে লাগাই; তৃতীয় স্তরের পরীক্ষা',
       15, (2, 255, 255), [
    (2, 255, 3, '<ila`h|N'), (2, 255, 6, 'Hay~|N'), (2, 255, 7, 'qay~uwm|N'),
    (2, 255, 12, 'nawom|N')],
    'আয়াতুল কুরসির শুরুর অংশ পড়ুন। এর প্রায় সব শব্দ এখন আপনি চেনেন: আল্লাহ, লা ইলাহা '
    'ইল্লা হুওয়া, আল-হাইয়ুল কাইয়ূম, লা তা’খুযুহু … ওয়ালা নাওম।', (2, 255, 3),
    checkpoint=True, word_to=12)

# The doc says a few lessons' example ayahs (e.g. 2:173 ending); every word above
# is checked against the DB, so a wrong reference stops the script.


# --------------------------------------------------------------- build
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--force', action='store_true')
    args = ap.parse_args()
    if (CONTENT / 'lemmas_bn.csv').exists() and not args.force:
        sys.exit('content/ already exists (it may hold teacher edits). Use --force to overwrite.')

    db = sqlite3.connect(DB)
    key_to_id = {k: i for i, k in db.execute('SELECT id, lemma_key FROM lemma')}
    lemma = {r[0]: r for r in db.execute(
        'SELECT id, lemma_key, root, pos, frequency, display_word_id FROM lemma')}

    def word(s, a, w):
        r = db.execute('SELECT id, text_uthmani FROM quran_word WHERE surah=? AND ayah=? '
                       'AND word_index=?', (s, a, w)).fetchone()
        if not r:
            sys.exit(f'No word {s}:{a}:{w}')
        return r

    def seg_lemmas(word_id):
        return [r[0] for r in db.execute(
            'SELECT lemma_id FROM word_segment WHERE word_id=? ORDER BY seg_index', (word_id,))]

    def ayah_words(s, a):
        return db.execute('SELECT id, word_index, text_uthmani FROM quran_word '
                          'WHERE surah=? AND ayah=? ORDER BY word_index', (s, a)).fetchall()

    def ayah_text(s, a):
        return ' '.join(t for _, _, t in ayah_words(s, a))

    taught, order_of = [], {}
    lessons_out, review = [], []
    by_id = {}
    for n, l in enumerate(L, start=1):
        new_ids, refs = [], []
        for s, a, w, key in l['words']:
            wid, text = word(s, a, w)
            if key not in key_to_id:
                sys.exit(f'{l["id"]}: unknown lemma key {key}')
            lid = key_to_id[key]
            if lid not in seg_lemmas(wid):
                sys.exit(f'{l["id"]}: word {s}:{a}:{w} does not contain {key}')
            if lid in order_of:
                sys.exit(f'{l["id"]}: {key} is already taught in {order_of[lid]}')
            if key not in M:
                sys.exit(f'{l["id"]}: no Bangla meaning for {key}')
            order_of[lid] = l['id']
            new_ids.append(lid)
            refs.append([s, a, w])
            span = db.execute('SELECT char_start, char_end FROM word_segment WHERE word_id=? '
                              'AND lemma_id=?', (wid, lid)).fetchone()
            part = text[span[0]:span[1]] if span and span[0] is not None else text
            review.append((lid, l['id'], text, part, f'{s}:{a}:{w}', key))
        taught += new_ids
        l['new'] = new_ids
        by_id[l['id']] = l
        known = list(taught)

        def distractors(lid, k=3):
            pool = [x for x in known if x != lid and M[lemma[x][1]][0] != M[lemma[lid][1]][0]]
            if len(pool) < k:
                pool += [x for x in key_to_id.values() if lemma[x][1] in M and x not in pool
                         and x != lid][:k]
            start = (lid * 7) % len(pool)
            return [pool[(start + i * 5) % len(pool)] for i in range(k)]

        s0, a0, a1 = l['anchor']
        steps = [{'type': 'ayah', 'surah': s0, 'ayah': a0}]
        if a1 != a0:
            steps[0]['ayah_to'] = a1
        if l['word_to']:
            steps[0]['word_to'] = l['word_to']
        if new_ids:
            steps.append({'type': 'words', 'lemma_ids': new_ids, 'word_refs': refs})
        ex = l['example']
        explain = {'type': 'explain', 'text_bn': l['explain'],
                   'example': {'surah': ex[0], 'ayah': ex[1], 'word_index': ex[2]}}
        for s, a, w in l['more']:
            word(s, a, w)
        if l['more']:
            explain['more_examples'] = [{'surah': s, 'ayah': a, 'word_index': w}
                                        for s, a, w in l['more']]
        word(*ex)
        steps.append(explain)

        items = []
        if l['checkpoint']:
            level_ids = [x for x in taught if order_of[x].startswith(f'L{l["level"]}-')]
            pick = sorted(level_ids, key=lambda x: -lemma[x][4])[:15]
            for i, lid in enumerate(pick):
                kind = 'mcq_bn_ar' if i % 4 == 3 else 'mcq_ar_bn'
                items.append({'kind': kind, 'lemma_id': lid, 'distractor_ids': distractors(lid)})
        else:
            for i, lid in enumerate(new_ids):
                kind = 'mcq_bn_ar' if i == len(new_ids) - 1 and len(new_ids) > 2 else 'mcq_ar_bn'
                items.append({'kind': kind, 'lemma_id': lid, 'distractor_ids': distractors(lid)})
            if not new_ids:  # review lesson: earlier words
                for lid in sorted(taught, key=lambda x: -lemma[x][4])[:8]:
                    items.append({'kind': 'mcq_ar_bn', 'lemma_id': lid,
                                  'distractor_ids': distractors(lid)})
        for key in l['listen']:
            lid = key_to_id[key]
            items.append({'kind': 'listen_choose', 'lemma_id': lid,
                          'distractor_ids': distractors(lid)})
        for s, a, w in l['split']:
            wid, _ = word(s, a, w)
            segs = db.execute('SELECT lemma_id, char_start FROM word_segment WHERE word_id=?',
                              (wid,)).fetchall()
            if len(segs) < 2 or any(c is None for _, c in segs):
                sys.exit(f'{l["id"]}: {s}:{a}:{w} cannot be split')
            if not all(x in taught for x, _ in segs):
                sys.exit(f'{l["id"]}: split {s}:{a}:{w} uses a part not taught yet')
            items.append({'kind': 'split', 'surah': s, 'ayah': a, 'word_index': w})
        if l['order']:
            s, a = l['order']
            if len(ayah_words(s, a)) > 8:
                sys.exit(f'{l["id"]}: ayah {s}:{a} too long to order')
            items.append({'kind': 'order', 'surah': s, 'ayah': a})
        steps.append({'type': 'quiz', 'items': items})

        if new_ids:
            recall = new_ids
        else:
            first, last = l['recall_from']
            ids = [x for x in taught if first <= order_of[x] <= last]
            recall = sorted(ids, key=lambda x: -lemma[x][4])[:10]
        steps.append({'type': 'recall', 'lemma_ids': recall})
        recap = {'type': 'ayah_recap', 'surah': s0, 'ayah': a0}
        if a1 != a0:
            recap['ayah_to'] = a1
        if l['word_to']:
            recap['word_to'] = l['word_to']
        steps.append(recap)

        lessons_out.append({
            'id': l['id'], 'level': l['level'], 'ord': n, 'title_bn': l['title'],
            'objective_bn': l['objective'], 'minutes': l['minutes'],
            'anchor_surah': s0, 'anchor_ayah_from': a0, 'anchor_ayah_to': a1,
            'reviewed_by': DRAFT, 'reviewed_on': '',
            'body': {'steps': steps},
        })

    # --- write
    (CONTENT / 'lessons').mkdir(parents=True, exist_ok=True)
    for f in (CONTENT / 'lessons').glob('*.json'):
        f.unlink()
    for lo in lessons_out:
        (CONTENT / 'lessons' / f'{lo["id"]}.json').write_text(
            json.dumps(lo, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    used = sorted(set(order_of))
    with open(CONTENT / 'lemmas_bn.csv', 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['lemma_id', 'lemma_key', 'lesson', 'meaning_bn', 'translit_bn', 'note_bn',
                    'reviewed_by', 'reviewed_on'])
        for lid in sorted(used, key=lambda x: (order_of[x], x)):
            m = M[lemma[lid][1]]
            w.writerow([lid, lemma[lid][1], order_of[lid], m[0], m[1], m[2], DRAFT, ''])

    from build_learn_db import BW_MAP  # noqa: E402
    roots = {}
    for lid in used:
        r = lemma[lid][2]
        if r:
            # back to the corpus's Buckwalter letters to find the idea
            inv = {v: chr(k) for k, v in BW_MAP.items()}
            roots[r] = ''.join(inv.get(c, c) for c in r.split(' '))
    missing = [k for k in roots.values() if not ROOT_IDEAS.get(k)]
    if missing:
        sys.exit(f'No Bangla idea for roots: {missing}')
    with open(CONTENT / 'roots_bn.csv', 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['root', 'meaning_bn', 'reviewed_by', 'reviewed_on'])
        for r, key in sorted(roots.items()):
            w.writerow([r, ROOT_IDEAS[key], DRAFT, ''])

    with open(CONTENT / 'REVIEW_SHEET.csv', 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['#', 'lesson', 'lemma_id', 'arabic_word (Tanzil)', 'word part taught (Tanzil)',
                    'anchor (surah:ayah:word)',
                    'anchor ayah (Tanzil)', 'type', 'root', 'meaning_bn (DRAFT)', 'translit_bn',
                    'note_bn', 'teacher: OK? (yes/no)', 'teacher: correct meaning',
                    'teacher: comment'])
        for i, (lid, les, text, part, ref, key) in enumerate(review, start=1):
            s, a, _ = map(int, ref.split(':'))
            m = M[key]
            w.writerow([i, les, lid, text, part, ref, ayah_text(s, a), lemma[lid][3],
                        lemma[lid][2] or '', m[0], m[1], m[2], '', '', ''])

    with open(CONTENT / 'REVIEW_TEXTS.csv', 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['kind', 'id', 'text_bn (DRAFT)', 'teacher: OK? (yes/no)',
                    'teacher: correction'])
        for lo in lessons_out:
            w.writerow(['lesson title', lo['id'], lo['title_bn'], '', ''])
            w.writerow(['lesson goal', lo['id'], lo['objective_bn'], '', ''])
            for st in lo['body']['steps']:
                if st['type'] == 'explain':
                    w.writerow(['explanation', lo['id'], st['text_bn'], '', ''])
        for r, key in sorted(roots.items()):
            w.writerow(['root idea', r, ROOT_IDEAS[key], '', ''])

    print(f'{len(lessons_out)} lessons, {len(used)} lemmas, {len(roots)} roots written to content/')


if __name__ == '__main__':
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    sys.path.insert(0, str(ROOT / 'tools'))
    main()
