#!/usr/bin/env python3
"""Level 2 (কুরআনের শব্দ) word list: the most frequent Quran words by lemma.

Source: Quranic Arabic Corpus, morphology version 0.4
(c) 2011 Kais Dukes, GNU General Public License - http://corpus.quran.com
The corpus builds on the Tanzil Uthmani text (tanzil.net).

Every Quran word has one stem segment carrying its lemma (LEM:). Prefixes
(wa-, bi-, al- ...) and attached pronouns are separate segments without a
lemma, so counting stem lemmas counts each word once. Coverage = share of all
Quran words whose lemma is in the list.

Usage: python3 tools/quran_word_frequency.py [path/to/quranic-corpus-morphology-0.4.txt]
Without a path the file is downloaded from a verbatim mirror and checked
against its SHA-256. Writes assets/arabic/level2_words.json and
docs/LEVEL2_WORDS.md. Bangla meanings stay empty: they are written and
checked by people.
"""

import collections
import hashlib
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIRROR = ('https://raw.githubusercontent.com/cltk/arabic_morphology_quranic-corpus/'
          'master/quranic-corpus-morphology-0.4.txt')
SHA256 = 'a1d12923815341face765083805d2148ed2d9f5cc3f7d6665219d887675d8c46'
TOP = 300

# Buckwalter transliteration as used by the corpus -> Arabic (Uthmani marks).
BW = {
    "'": 'ء', '>': 'أ', '&': 'ؤ', '<': 'إ', '}': 'ئ', 'A': 'ا', 'b': 'ب',
    'p': 'ة', 't': 'ت', 'v': 'ث', 'j': 'ج', 'H': 'ح', 'x': 'خ', 'd': 'د',
    '*': 'ذ', 'r': 'ر', 'z': 'ز', 's': 'س', '$': 'ش', 'S': 'ص', 'D': 'ض',
    'T': 'ط', 'Z': 'ظ', 'E': 'ع', 'g': 'غ', '_': 'ـ', 'f': 'ف', 'q': 'ق',
    'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن', 'h': 'ه', 'w': 'و', 'Y': 'ى',
    'y': 'ي', 'F': 'ً', 'N': 'ٌ', 'K': 'ٍ', 'a': 'َ', 'u': 'ُ', 'i': 'ِ',
    '~': 'ّ', 'o': 'ْ', '^': 'ٓ', '#': 'ٔ', '`': 'ٰ', '{': 'ٱ', ':': 'ۜ',
    '@': '۟', '"': '۠', '[': 'ۢ', ';': 'ۣ', ',': 'ۥ', '.': 'ۦ', '!': 'ۨ',
    '-': '۪', '+': '۫', '%': '۬', ']': 'ۭ',
}
BW_MAP = {ord(k): v for k, v in BW.items()}

POS_BN = {
    'N': 'বিশেষ্য', 'PN': 'নাম', 'ADJ': 'বিশেষণ', 'V': 'ক্রিয়া', 'PRON': 'সর্বনাম',
    'DEM': 'ইঙ্গিতবাচক', 'REL': 'সম্বন্ধবাচক', 'P': 'অব্যয় (হরফ)', 'NEG': 'না-বোধক',
    'CONJ': 'সংযোজক', 'T': 'সময়বাচক', 'LOC': 'স্থানবাচক', 'ACC': 'হরফ', 'COND': 'শর্তবাচক',
    'INTG': 'প্রশ্নবোধক', 'SUB': 'সংযোজক', 'RES': 'সীমাবোধক', 'EXP': 'ব্যতিক্রমবোধক',
    'FUT': 'ভবিষ্যৎবোধক', 'CERT': 'নিশ্চয়তাবোধক', 'VOC': 'সম্বোধন', 'AMD': 'সংশোধক',
    'ANS': 'উত্তরবোধক', 'AVR': 'প্রতিবাদবোধক', 'CAUS': 'কারণবোধক', 'CIRC': 'অবস্থাবোধক',
    'COM': 'সহগামী', 'EMPH': 'জোরবোধক', 'EQ': 'সমতাবোধক', 'EXH': 'উৎসাহবোধক',
    'EXL': 'ব্যাখ্যাবোধক', 'IMPN': 'আদেশবোধক', 'INC': 'সূচনাবোধক', 'INT': 'ব্যাখ্যাবোধক',
    'PRO': 'নিষেধবোধক', 'PREV': 'বাধাবোধক', 'PRP': 'উদ্দেশ্যবোধক', 'RET': 'প্রত্যাহারবোধক',
    'RSLT': 'ফলবোধক', 'SUP': 'অতিরিক্ত', 'SUR': 'বিস্ময়বোধক', 'INL': 'মুকাত্তাআত',
}


def load(path=None):
    if path:
        data = pathlib.Path(path).read_bytes()
    else:
        with urllib.request.urlopen(MIRROR) as r:
            data = r.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        sys.exit('corpus file does not match the expected v0.4 checksum')
    return data.decode('utf-8')


def main():
    text = load(sys.argv[1] if len(sys.argv) > 1 else None)
    words = set()
    lemmas = collections.Counter()
    info = {}
    forms = collections.defaultdict(collections.Counter)
    first = {}
    word_text = collections.defaultdict(str)
    rows = [l.split('\t') for l in text.splitlines() if l.startswith('(')]
    # Whole word (all segments joined) for the example form.
    for loc, form, _tag, _feat in rows:
        s, a, w, _seg = loc[1:-1].split(':')
        word_text[(int(s), int(a), int(w))] += form
    for loc, form, tag, feat in rows:
        s, a, w, _seg = loc[1:-1].split(':')
        key = (int(s), int(a), int(w))
        words.add(key)
        if 'STEM' not in feat.split('|'):
            continue
        m = re.search(r'LEM:([^|]+)', feat)
        if not m:
            continue
        lem = m.group(1)
        root = re.search(r'ROOT:([^|]+)', feat)
        pos = re.search(r'POS:([^|]+)', feat)
        lemmas[lem] += 1
        info.setdefault(lem, (root.group(1) if root else '', pos.group(1) if pos else tag))
        forms[lem][word_text[key]] += 1
        first.setdefault(lem, key)

    total_words = len(words)
    total_stems = sum(lemmas.values())
    top = lemmas.most_common(TOP)
    covered = sum(n for _, n in top)
    out = []
    running = 0
    for rank, (lem, n) in enumerate(top, 1):
        root, pos = info[lem]
        running += n
        s, a, w = first[lem]
        out.append({
            'rank': rank,
            # Some lemmas keep the shadda of an assimilated al- on the first letter.
            'lemma': re.sub(r'^(.)[~o]', r'\1', lem).translate(BW_MAP),
            'lemma_buckwalter': lem,
            # The corpus writes a hamza root letter as A.
            'root': ' '.join(root.replace('A', '>').translate(BW_MAP)) if root else '',
            'pos': pos,
            'pos_bn': POS_BN.get(pos, pos),
            'count': n,
            'percent': round(100 * n / total_words, 3),
            'cumulative_percent': round(100 * running / total_words, 2),
            'common_form': forms[lem].most_common(1)[0][0].translate(BW_MAP),
            'first_ref': f'{s}:{a}',
            'bn': '',
        })

    coverage = round(100 * covered / total_words, 2)
    credit = ('Quranic Arabic Corpus, morphology v0.4, (c) 2011 Kais Dukes, '
              'GNU General Public License, http://corpus.quran.com — built on the '
              'Tanzil Uthmani text (tanzil.net).')
    result = {
        'source': credit,
        'method': 'Each Quran word counted once by the lemma of its stem; prefixes and '
                  'attached pronouns are not counted as separate words.',
        'total_words': total_words,
        'distinct_lemmas': len(lemmas),
        'top': TOP,
        'coverage_percent': coverage,
        'words': out,
    }
    dst = ROOT / 'assets' / 'arabic' / 'level2_words.json'
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(result, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')

    marks = [10, 50, 100, 200, 300]
    lines = [
        '# Level 2 (কুরআনের শব্দ): the 300 most frequent Quran words',
        '',
        f'Source: {credit}',
        '',
        'Generated by `tools/quran_word_frequency.py`. Each of the '
        f'{total_words:,} Quran words is counted once, by the lemma (dictionary form) '
        'of its stem. Prefixes such as وَ، بِ، لِ، الـ and attached pronouns are not '
        'counted as separate words.',
        '',
        f'- Quran words: **{total_words:,}**, distinct lemmas: **{len(lemmas):,}**',
        f'- The top **{TOP}** lemmas cover **{coverage}%** of all Quran words.',
        '- Coverage by list size: ' + ', '.join(
            f'top {k}: {out[k - 1]["cumulative_percent"]}%' for k in marks),
        '',
        'The Bangla meaning column is empty on purpose: meanings are to be written and '
        'checked by a qualified person, then filled in `assets/arabic/level2_words.json` '
        '(`bn`).',
        '',
        '| # | Lemma | Root | Type | Count | Cumulative % | Common form | First (surah:ayah) | Bangla |',
        '|---|---|---|---|---|---|---|---|---|',
    ]
    for r in out:
        lines.append(
            f'| {r["rank"]} | {r["lemma"]} | {r["root"]} | {r["pos_bn"]} | {r["count"]} | '
            f'{r["cumulative_percent"]} | {r["common_form"]} | {r["first_ref"]} |  |')
    lines += [
        '',
        '---',
        '',
        'Copyright notice of the source, reproduced as its terms of use require:',
        '',
        '```',
        *[l for l in text.splitlines()[:27] if l.startswith('#')],
        '```',
        '',
    ]
    (ROOT / 'docs' / 'LEVEL2_WORDS.md').write_text('\n'.join(lines), encoding='utf-8')
    print(f'words {total_words}, stems {total_stems}, lemmas {len(lemmas)}, '
          f'top {TOP} cover {coverage}%')


if __name__ == '__main__':
    main()
