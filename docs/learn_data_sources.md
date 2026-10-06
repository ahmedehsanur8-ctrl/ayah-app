# কুরআন বুঝি: data sources and licences (Phase 1)

The content DB `assets/learn/learn_content.db` is built by `tools/learn/build_learn_db.py`
(and on GitHub by `.github/workflows/learn-data.yml`). The latest build numbers are in
`tools/data/learn_report.txt`.

## Arabic text: Tanzil

- **What:** Tanzil Quran Text, Uthmani, the same file the app already bundles
  (`assets/quran/arabic.txt.gz`, written verbatim by `tools/fetch_quran.py`).
  Every Arabic word in the DB (`quran_word.text_uthmani`) is cut from that file at the
  spaces, character for character. The build checks that every ayah's words, put back
  together, are exactly the Tanzil ayah (all 6,236 pass).
- **Licence:** Creative Commons Attribution 3.0 with Tanzil's terms (verbatim copies only;
  credit Tanzil and link to tanzil.net). The notice is stored in the DB (`meta.tanzil_notice`)
  and is already shown on the app's Credits page.
- **Live check:** tanzil.net is blocked from the build computer used here, so the GitHub
  workflow runs the build with `--check-tanzil`. It downloads the live text and fails if
  it differs from the bundled copy.
- **First run, 1 Oct 2026:** tanzil.net's HTTPS certificate **had expired**, so the live
  check could not run. Verification is never switched off, so the build used the bundled
  copy. That copy was downloaded from Tanzil on 28 Sep 2026 (`assets/quran/meta.json`,
  `generatedAt`) by the "Quran data" workflow.
- **Later run, 2 Oct 2026:** the certificate worked again and the check passed: the bundled
  text is **identical to the live tanzil.net download** (`tools/data/learn_report.txt`).

## Word grammar (morphology): Quranic Arabic Corpus v0.4

| | Official | Used for the build |
|---|---|---|
| Where | https://corpus.quran.com/download/ | https://raw.githubusercontent.com/cltk/arabic_morphology_quranic-corpus/master/quranic-corpus-morphology-0.4.txt |
| Who | Kais Dukes, University of Leeds | GitHub repo `cltk/arabic_morphology_quranic-corpus` (Classical Language Toolkit), a copy of the official file |
| Licence | GNU General Public License + terms of use (below) | The repo has **no licence of its own** (no LICENSE file; the README is only a title). The file keeps the corpus's own copyright block, so the **corpus licence applies unchanged** |
| Reachable from here | **No** (blocked) | Yes |
| SHA-256 | Compared on GitHub by the workflow | `a1d12923815341face765083805d2148ed2d9f5cc3f7d6665219d887675d8c46` |

**How the two were compared:**
- The mirror file starts with the official copyright block for "Quranic Arabic Corpus
  (morphology, version 0.4), Copyright (C) 2011 Kais Dukes, License: GNU General Public
  License", followed by the Tanzil Uthmani 1.0.2 block. It has 128,219 segments and
  77,429 words, which matches every one of the 6,236 Tanzil ayahs word for word.
- The build pins the file's SHA-256. On GitHub the workflow tries the official site
  first and accepts it only if it has the same checksum, so a different file can never
  slip in.
- **Result on GitHub, 1 Oct 2026:**
  - `https://corpus.quran.com/download/` answers (HTTP 200), but the file is behind a
    **download form** that the page submits with JavaScript (`document.downloadForm.submit()`).
  - The direct address returns that HTML page (9,187 bytes), not the corpus file.
  - So the official file cannot be fetched automatically to compare checksums. The build
    uses the mirror, and the pinned checksum guarantees it is always the same file.
- **To compare byte for byte:** download the file once by hand from corpus.quran.com/download
  (accept the terms) and run
  `python3 tools/learn/build_learn_db.py --qac path/to/quranic-corpus-morphology-0.4.txt`.
  It stops with an error if the official file differs from the mirror's checksum.

**Terms of use (from the file itself):**
- Verbatim copies only; **changing the file is not allowed**. The build does not change
  it: it reads it and stores derived tables.
- It "can be used in any website or application, provided its source (the Quranic
  Arabic Corpus) is clearly indicated, and a link is made to http://corpus.quran.com".
- The copyright notice must be "reproduced appropriately in all works derived from or
  containing substantial portion of this file". It is stored in the DB
  (`meta.qac_notice`) and **will be shown on the Credits page** once the feature ships
  (Phase 3/5).

The corpus FAQ also asks for non-commercial use (see the spec, A2). Ayah Reminder is
free with no ads, so this is met. A paid tier would need written permission first.

## What comes from where (Arabic rule)

| Shown in the app | Source |
|---|---|
| Any Quran word or ayah | Tanzil, by `quran_word` id |
| A lemma (dictionary word) | Shown through a real Tanzil word: `lemma.display_word_id`, or a lesson's anchor ayah |
| A prefix or attached pronoun (e.g. بِ in بِسْمِ) | A slice of the Tanzil word: `word_segment.char_start` / `char_end` |
| `lemma.lemma_ar`, `lemma.root` | Corpus spelling, for matching and search only; **never shown as Quran text** |

## Additions to the spec's tables

| Addition | Why |
|---|---|
| `meta` | Content version and the Tanzil and corpus notices |
| `word_segment` | Prefix/stem/suffix of each word, with its character span in the Tanzil word; used for "split" quizzes and for teaching ب, ل, و, ال, ـنا … |
| `lemma.lemma_key` | Stable key: corpus lemma + part of speech |
| `lemma.rank` | Frequency rank |
| `lemma.display_word_id` | The Tanzil word used to show a lemma |
| `root_info` | One short Bangla idea per root (authored, `content/roots_bn.csv`), behind the "মূল অক্ষর দেখুন" button |
| Prefix/pronoun keys | Include the written form (e.g. `PRON:3MP` as ـهُمْ "their" vs ـوا "they did"), because the corpus tags both the same |

Lemma ids follow first occurrence in the Quran, so they stay the same across rebuilds and
saved review cards stay valid.

## Numbers (from `tools/data/learn_report.txt`)

- 77,429 words, 128,219 segments, 4,924 stem lemmas, plus 99 pronoun and prefix/suffix
  entries.
- **Joined words.** The corpus follows Tanzil 1.0.2. The newer Tanzil text writes 4 words
  as two tokens (بَعْدَ مَا in 2:181, 8:6, 13:37 and إِلْ يَاسِينَ in 37:130). Each pair
  is stored as one word with its original space.
- **Prefix/suffix positions** were found for 77,218 words. The other 211 are mostly the
  "my" ending written only as a kasra (رَبِّ = "my Lord"); for these the whole word is
  highlighted.
- **Coverage of all Quran words by the most frequent lemmas:**

  | Most frequent lemmas | Share of all Quran words |
  |---|---|
  | 10 | 23.4% |
  | 50 | 44.1% |
  | 100 | 53.8% |
  | 150 | 59.5% |
  | 300 | 69.9% |
  | 500 | 77.2% |

  This counts each word once, by its main word. Prefixes and attached pronouns are not
  counted separately, so these percentages are lower than the "125 words = 50%"
  marketing figures.
- **DB size:** 14.35 MB on disk, 4.53 MB compressed (with the 30 draft lessons). That is under the spec's 15 MB
  compressed target.
