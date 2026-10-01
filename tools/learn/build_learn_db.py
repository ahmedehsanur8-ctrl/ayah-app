#!/usr/bin/env python3
"""কুরআন বুঝি: builds the bundled, read-only content DB assets/learn/learn_content.db.

Sources
  * Arabic text: Tanzil.net, Uthmani (the same file the app bundles,
    assets/quran/arabic.txt.gz, written verbatim by tools/fetch_quran.py).
    With --check-tanzil the live Tanzil download is fetched and must be
    identical to the bundled copy.
  * Morphology: Quranic Arabic Corpus, morphology version 0.4
    (c) 2011 Kais Dukes, GNU General Public License, http://corpus.quran.com
    Downloaded from the official site if it answers, otherwise from the
    verbatim CLTK mirror on GitHub; either way the file must match the pinned
    SHA-256, so it is byte-for-byte the same file.

What it does
  1. Splits every Tanzil ayah into words (stand-alone waqf marks such as ۚ are
     not words; the basmala Tanzil writes in front of ayah 1 of most surahs is
     not part of that ayah).
  2. Aligns the corpus words (surah:ayah:word) with the Tanzil words. The word
     counts must agree in every ayah, or the build fails.
  3. For every corpus segment (prefix, stem, suffix) finds which characters of
     the Tanzil word it covers, so the app can highlight e.g. the بِ in بِسْمِ
     while still only showing Tanzil text.
  4. Groups words by lemma (the stem's LEM: plus its part of speech) and
     counts frequencies; prefixes and attached pronouns get their own entries
     ("affix lemmas") because the first lessons teach them.
  5. Writes the tables from docs/learn_arabic_spec.md (quran_word, lemma,
     lesson, lesson_lemma) plus word_segment and meta.

Arabic text rule: no Arabic is typed or generated here. quran_word.text_uthmani
is the Tanzil word, character for character. lemma.lemma_ar is the corpus's own
lemma spelling (converted from its Buckwalter letters) and is used only for
matching and search; the app never shows it (it shows a Tanzil word instead,
lemma.display_word_id).

Lemma ids are stable: they follow the order in which each lemma first occurs
in the Quran, so rebuilding with the same sources gives the same ids (saved
review cards point at them).

Usage: python3 tools/learn/build_learn_db.py [--check-tanzil] [--qac PATH]
"""

import argparse
import collections
import gzip
import hashlib
import json
import pathlib
import sqlite3
import sys
import unicodedata
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from quran_word_frequency import BW_MAP, POS_BN  # noqa: E402  (same Buckwalter table)

OUT = ROOT / 'assets' / 'learn' / 'learn_content.db'
CACHE = ROOT / 'build' / 'learn'
REPORT = ROOT / 'tools' / 'data' / 'learn_report.txt'

# Bump when the DB changes in a way the app must notice (it re-copies the asset).
CONTENT_VERSION = 1

QAC_SHA256 = 'a1d12923815341face765083805d2148ed2d9f5cc3f7d6665219d887675d8c46'
QAC_OFFICIAL = [
    'https://corpus.quran.com/download/quranic-corpus-morphology-0.4.txt',
]
QAC_MIRROR = ('https://raw.githubusercontent.com/cltk/arabic_morphology_quranic-corpus/'
              'master/quranic-corpus-morphology-0.4.txt')
TANZIL_TEXT_URL = (
    'https://tanzil.net/pub/download/index.php?'
    'marks=true&sajdah=true&rub=false&tatweel=true&quranType=uthmani'
    '&outType=txt-2&agree=true'
)

# Parts of speech that count as one "noun" lemma (a word used as noun and adjective
# is still one word to learn). Particles keep their POS: مَا "what" and مَا "not"
# are different words to a learner.
NOUN_GROUP = {'N', 'ADJ'}


def log(*a):
    print(*a, flush=True)


def fetch(url, timeout=60):
    req = urllib.request.Request(url, headers={'User-Agent': 'ayah-reminder-build/1.0'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


# ------------------------------------------------------------------ sources

def load_qac(path):
    """Returns (bytes, source description)."""
    if path:
        data = pathlib.Path(path).read_bytes()
        source = f'local file {path}'
    else:
        cached = CACHE / 'quranic-corpus-morphology-0.4.txt'
        data, source = None, None
        for url in QAC_OFFICIAL + [QAC_MIRROR]:
            try:
                d = fetch(url)
            except Exception as e:  # noqa: BLE001
                log(f'  QAC: {url} -> {e.__class__.__name__}: {e}')
                continue
            if hashlib.sha256(d).hexdigest() != QAC_SHA256:
                log(f'  QAC: {url} -> different file (sha256 mismatch), skipped')
                continue
            data, source = d, url
            break
        if data is None and cached.exists():
            data, source = cached.read_bytes(), f'cache {cached}'
        if data is None:
            sys.exit('Could not get the Quranic Arabic Corpus file.')
        CACHE.mkdir(parents=True, exist_ok=True)
        cached.write_bytes(data)
    if hashlib.sha256(data).hexdigest() != QAC_SHA256:
        sys.exit('QAC file does not match the pinned SHA-256 (not the verbatim v0.4 file).')
    return data, source


def load_tanzil(check_live):
    raw = gzip.open(ROOT / 'assets/quran/arabic.txt.gz', 'rt', encoding='utf-8').read()
    lines = raw.split('\n')
    meta = json.loads((ROOT / 'assets/quran/meta.json').read_text(encoding='utf-8'))
    assert len(lines) == meta['total'] == 6236, len(lines)
    verses = {}
    for s in meta['surahs']:
        for a in range(1, s['ayahs'] + 1):
            verses[(s['n'], a)] = lines[s['start'] + a - 1]
    status = 'not checked (run with --check-tanzil)'
    if check_live:
        try:
            live = fetch(TANZIL_TEXT_URL).decode('utf-8')
            lv = {}
            for line in live.splitlines():
                p = line.split('|')
                if len(p) == 3 and p[0].isdigit():
                    lv[(int(p[0]), int(p[1]))] = p[2]
            diff = [k for k in verses if lv.get(k) != verses[k]]
            if diff:
                sys.exit(f'Live Tanzil text differs from the bundled copy in {len(diff)} ayahs, '
                         f'first {diff[:5]}. Run the "Quran data" workflow first.')
            status = 'identical to the live tanzil.net download'
        except SystemExit:
            raise
        except Exception as e:  # noqa: BLE001
            status = f'live check failed ({e.__class__.__name__}: {e}); used the bundled copy'
    return verses, meta, status


# ------------------------------------------------------------------ parsing

def is_word(token):
    return any(unicodedata.category(c).startswith('L') and c != 'ـ' for c in token)


def letter_key(s):
    return ''.join(c for _, c in letters(s)).translate(NORM)


def tanzil_words(verses):
    """Tanzil tokens per ayah, without the basmala Tanzil puts in front of ayah 1
    (some surahs write it with an extra mark, e.g. بِّسْمِ, so it is matched by letters)."""
    basmala = verses[(1, 1)].split(' ')
    nb = len(basmala)
    words = {}
    for (s, a), text in verses.items():
        toks = text.split(' ')
        if (a == 1 and s not in (1, 9) and len(toks) > nb
                and [letter_key(t) for t in toks[:nb]] == [letter_key(t) for t in basmala]):
            toks = toks[nb:]
        words[(s, a)] = [t for t in toks if t and is_word(t)]
    return words


def join_split_words(tokens, qac_words):
    """The corpus follows Tanzil 1.0.2. Newer Tanzil writes a few words as two
    tokens (بَعْدَ مَا, إِلْ يَاسِينَ) where the corpus has one word. Joins those
    Tanzil tokens with their original space, so the text stays verbatim.
    Returns (words, joins) or (None, None) if the letters do not line up."""
    out, joins, i = [], [], 0
    for qw in qac_words:
        want = letter_key(qw)
        if i >= len(tokens):
            return None, None
        got, j = letter_key(tokens[i]), i + 1
        while got != want and j < len(tokens) and want.startswith(got):
            got += letter_key(tokens[j])
            j += 1
        if got != want and len(tokens) == len(qac_words):
            # same count: a spelling difference inside one word; keep 1:1
            j = i + 1
        elif got != want:
            return None, None
        if j - i > 1:
            joins.append(' '.join(tokens[i:j]))
        out.append(' '.join(tokens[i:j]))
        i = j
    return (out, joins) if i == len(tokens) else (None, None)


def parse_qac(data):
    """{(s, a): {w: [segment dicts]}} plus the two copyright blocks."""
    text = data.decode('utf-8')
    header = []
    for line in text.splitlines():
        if line.startswith('#') or not line.strip():
            header.append(line)
            continue
        break
    segs = collections.defaultdict(lambda: collections.defaultdict(list))
    for line in text.splitlines():
        if not line.startswith('('):
            continue
        loc, form, tag, feats = line.split('\t')
        s, a, w, k = map(int, loc.strip('()').split(':'))
        f = feats.split('|')
        kind = f[0]  # PREFIX / STEM / SUFFIX
        props = {}
        for x in f[1:]:
            if ':' in x:
                key, val = x.split(':', 1)
                props[key] = val
        segs[(s, a)][w].append({
            'k': k, 'form': form, 'tag': tag, 'feats': feats, 'kind': kind, 'props': props,
        })
    return segs, '\n'.join(header).strip()


def bw(s):
    return s.translate(BW_MAP)


# Tanzil writes some letters as small signs where the corpus writes a full letter
# (dagger alif ٰ for ا, hamza above ٔ on a tatweel for ء); they count as letters.
SIGN_LETTERS = {'\u0670': 'ا', '\u0654': 'ء', '\u0655': 'ء'}


def letters(s):
    """Base letters (no other marks, no tatweel), as a list of (index, char)."""
    return [(i, SIGN_LETTERS.get(c, c)) for i, c in enumerate(s)
            if (unicodedata.category(c) == 'Lo' and c != 'ـ') or c in SIGN_LETTERS]


NORM = str.maketrans({'ى': 'ي', 'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٲ': 'ا', 'ٳ': 'ا',
                      'ؤ': 'ء', 'ئ': 'ء', 'ۦ': 'ي', 'ۥ': 'و'})


def spans(token, seg_list):
    """Character span of each segment inside the Tanzil token, or None."""
    tl = letters(token)
    seg_letters = [[c for _, c in letters(bw(sg['form']))] for sg in seg_list]
    flat = [c for sl in seg_letters for c in sl]
    if len(flat) != len(tl) or any(a.translate(NORM) != b.translate(NORM)
                                   for a, (_, b) in zip(flat, tl)):
        return None
    out, pos = [], 0
    for i, sl in enumerate(seg_letters):
        if not sl:
            return None
        start = tl[pos][0] if i > 0 else 0
        pos += len(sl)
        end = tl[pos][0] if pos < len(tl) else len(token)
        out.append((start, end))
    return out


# ------------------------------------------------------------------ build

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check-tanzil', action='store_true',
                    help='download Tanzil and require it to equal the bundled copy')
    ap.add_argument('--qac', help='path to quranic-corpus-morphology-0.4.txt')
    args = ap.parse_args()

    log('Tanzil text ...')
    verses, meta, tanzil_status = load_tanzil(args.check_tanzil)
    log(f'  {tanzil_status}')
    log('Quranic Arabic Corpus ...')
    qac_bytes, qac_source = load_qac(args.qac)
    log(f'  from {qac_source}')
    segs, qac_header = parse_qac(qac_bytes)

    tw = tanzil_words(verses)

    # 1. align words (Tanzil tokens -> corpus words)
    bad, all_joins = [], []
    for key in sorted(verses):
        q = segs.get(key, {})
        if sorted(q) != list(range(1, len(q) + 1)):
            bad.append((key, len(tw[key]), len(q)))
            continue
        if len(q) != len(tw[key]):
            qac_words = [''.join(bw(x['form']) for x in sorted(q[w], key=lambda x: x['k']))
                         for w in sorted(q)]
            joined, joins = join_split_words(tw[key], qac_words)
            if joined is None or len(joined) != len(q):
                bad.append((key, len(tw[key]), len(q)))
                continue
            tw[key] = joined
            all_joins += [f'{key[0]}:{key[1]} {j}' for j in joins]
    if bad:
        for b in bad[:20]:
            log('  word count mismatch', b)
        sys.exit(f'{len(bad)} ayahs have different word counts in Tanzil and the corpus.')

    # 2. lemmas (stable ids by first occurrence)
    lemma_index = {}   # key -> id
    lemma_rows = {}    # id -> dict
    def lemma_for(key, lemma_ar, root, pos, word_id):
        if key not in lemma_index:
            i = len(lemma_index) + 1
            lemma_index[key] = i
            lemma_rows[i] = {'key': key, 'lemma_ar': lemma_ar, 'root': root, 'pos': pos,
                             'freq': 0, 'display_word_id': word_id}
        return lemma_index[key]

    words, segments = [], []
    span_fail = 0
    no_stem_lemma = 0
    wid = 0
    for (s, a) in sorted(verses):
        for w, token in enumerate(tw[(s, a)], start=1):
            wid += 1
            sl = sorted(segs[(s, a)][w], key=lambda x: x['k'])
            sp = spans(token, sl)
            if sp is None:
                span_fail += 1
            stem = next((x for x in sl if x['kind'] == 'STEM'), None)
            stem_lemma, root, pos = None, None, None
            if stem is not None:
                pos = stem['tag']
                root_bw = stem['props'].get('ROOT')
                root = ' '.join(bw(root_bw)) if root_bw else None
                lem = stem['props'].get('LEM')
                if lem:
                    group = 'N' if pos in NOUN_GROUP else pos
                    stem_lemma = lemma_for(f'{lem}|{group}', bw(lem), root, group, wid)
                elif pos == 'PRON':
                    # separate pronouns (هُوَ، هُمْ …) have no LEM: one entry per person
                    person = next((x for x in stem['feats'].split('|')[2:] if ':' not in x), '')
                    stem_lemma = lemma_for(f'PRON|{person}', None, None, 'PRON', wid)
                else:
                    no_stem_lemma += 1
            words.append((wid, s, a, w, token, stem_lemma, root, pos,
                          ' + '.join(x['tag'] + '|' + x['feats'] for x in sl)))
            for i, x in enumerate(sl):
                if x['kind'] == 'STEM':
                    lid = stem_lemma
                else:
                    # prefixes and attached pronouns: one entry per feature, e.g.
                    # PREFIX|bi+ or SUFFIX|PRON:1P
                    lid = lemma_for(f'AFFIX|{x["feats"]}', None, None, x['tag'], wid)
                if lid:
                    lemma_rows[lid]['freq'] += 1
                start, end = sp[i] if sp else (None, None)
                segments.append((wid, i + 1, x['kind'].lower(), lid, x['tag'], start, end))

    # rank by frequency (1 = most frequent), stem lemmas and affixes together
    order = sorted(lemma_rows, key=lambda i: (-lemma_rows[i]['freq'], i))
    for r, i in enumerate(order, start=1):
        lemma_rows[i]['rank'] = r

    # 3. write the DB
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tmp = OUT.with_suffix('.tmp')
    if tmp.exists():
        tmp.unlink()
    db = sqlite3.connect(tmp)
    db.executescript('''
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
    CREATE TABLE quran_word (
      id INTEGER PRIMARY KEY,
      surah INTEGER, ayah INTEGER, word_index INTEGER,
      text_uthmani TEXT,
      lemma_id INTEGER, root TEXT,
      pos TEXT, features TEXT,
      UNIQUE (surah, ayah, word_index));
    CREATE TABLE word_segment (
      word_id INTEGER, seg_index INTEGER, kind TEXT, lemma_id INTEGER,
      tag TEXT, char_start INTEGER, char_end INTEGER,
      PRIMARY KEY (word_id, seg_index)) WITHOUT ROWID;
    CREATE TABLE lemma (
      id INTEGER PRIMARY KEY, lemma_ar TEXT, root TEXT,
      pos TEXT, frequency INTEGER,
      meaning_bn TEXT,
      translit_bn TEXT, note_bn TEXT,
      audio_key TEXT, reviewed_by TEXT, reviewed_on TEXT,
      lemma_key TEXT UNIQUE, rank INTEGER, display_word_id INTEGER);
    CREATE TABLE lesson (
      id TEXT PRIMARY KEY,
      level INTEGER, ord INTEGER, title_bn TEXT, objective_bn TEXT,
      minutes INTEGER, anchor_surah INTEGER, anchor_ayah_from INTEGER, anchor_ayah_to INTEGER,
      body_json TEXT,
      content_version INTEGER);
    CREATE TABLE lesson_lemma (lesson_id TEXT, lemma_id INTEGER, ord INTEGER,
      PRIMARY KEY (lesson_id, lemma_id));
    ''')
    db.executemany('INSERT INTO quran_word VALUES (?,?,?,?,?,?,?,?,?)', words)
    db.executemany('INSERT INTO word_segment VALUES (?,?,?,?,?,?,?)', segments)
    db.executemany(
        'INSERT INTO lemma (id, lemma_ar, root, pos, frequency, lemma_key, rank, display_word_id) '
        'VALUES (?,?,?,?,?,?,?,?)',
        [(i, r['lemma_ar'], r['root'], r['pos'], r['freq'], r['key'], r['rank'],
          r['display_word_id']) for i, r in sorted(lemma_rows.items())])
    tanzil_notice = meta['arabic'].get('licenseHeader', '').strip()
    db.executemany('INSERT INTO meta VALUES (?,?)', [
        ('content_version', str(CONTENT_VERSION)),
        ('tanzil_notice', tanzil_notice),
        ('tanzil_url', 'https://tanzil.net'),
        ('tanzil_version', str(meta['arabic'].get('version', ''))),
        ('qac_notice', qac_header),
        ('qac_url', 'https://corpus.quran.com'),
        ('qac_source', qac_source),
        ('qac_sha256', QAC_SHA256),
    ])
    db.execute('CREATE INDEX quran_word_lemma ON quran_word (lemma_id)')
    db.execute('CREATE INDEX word_segment_lemma ON word_segment (lemma_id)')
    db.commit()
    db.execute('VACUUM')
    db.close()
    tmp.replace(OUT)

    # 4. report
    stems = [r for r in lemma_rows.values() if not r['key'].startswith(('AFFIX|', 'PRON|'))]
    affixes = len(lemma_rows) - len(stems)
    total_words = len(words)
    cover = collections.Counter()
    by_freq = sorted((r['freq'] for r in stems), reverse=True)
    run = 0
    for n, f in enumerate(by_freq, start=1):
        run += f
        if n in (10, 50, 100, 150, 300, 500):
            cover[n] = run / total_words * 100
    size = OUT.stat().st_size
    gz = len(gzip.compress(OUT.read_bytes(), 9))
    report = [
        'কুরআন বুঝি content DB (tools/learn/build_learn_db.py)',
        f'Tanzil text: {tanzil_status}',
        f'QAC source: {qac_source} (sha256 {QAC_SHA256})',
        f'Words (Tanzil = corpus, every ayah): {total_words}',
        f'Tanzil tokens joined into one corpus word ({len(all_joins)}): ' + '; '.join(all_joins),
        f'Segments: {len(segments)}; character spans found for '
        f'{total_words - span_fail} words ({span_fail} without spans)',
        f'Words without a stem lemma: {no_stem_lemma}',
        f'Lemmas: {len(stems)} stem lemmas + {affixes} pronoun and prefix/suffix entries',
        'Coverage of all Quran words by the most frequent stem lemmas: '
        + ', '.join(f'top {n}: {cover[n]:.2f}%' for n in sorted(cover)),
        f'DB size: {size / 1e6:.2f} MB ({gz / 1e6:.2f} MB gzip-compressed)',
    ]
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text('\n'.join(report) + '\n', encoding='utf-8')
    log('\n'.join(report))


if __name__ == '__main__':
    main()
