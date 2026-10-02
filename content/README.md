# কুরআন বুঝি: lesson content (Levels 1–3)

Everything here is a **DRAFT** written for internal testing. A qualified Arabic/Quran
teacher must check it before the app is released to the public. In the app, every draft
word shows a small "খসড়া" badge.

## For the teacher

1. Open **`REVIEW_SHEET.csv`** in Excel or Google Sheets. It has one row per word, 130 in all.
   Each row shows:
   - the Arabic word as it appears in the Quran (Tanzil text);
   - the part being taught (for example only بِ in بِسْمِ);
   - the ayah it comes from;
   - the draft Bangla meaning.

   In the three "teacher" columns, write *yes* if the meaning is right; otherwise write
   the correct meaning, plus any comment.
2. Open **`REVIEW_TEXTS.csv`**. It holds the lesson titles, goals, the short Bangla
   explanation in each lesson, and the one-line idea for each root (মূল অক্ষর). Check
   them in the same way.
3. Send both files back. The corrections then go into `lemmas_bn.csv`, `roots_bn.csv`
   and `lessons/*.json`, and `reviewed_by` changes from `DRAFT` to the teacher's name
   and date.

Meanings are short and literal on purpose: no tafsir, no rulings.

## Files

| File | What it is |
|---|---|
| `lemmas_bn.csv` | Bangla meaning per word (lemma), keyed by `lemma_id` + `lemma_key` |
| `roots_bn.csv` | One short Bangla idea per root, shown behind the "মূল অক্ষর দেখুন" button |
| `lessons/L*.json` | The 30 lessons in the spec's `body_json` format |
| `REVIEW_SHEET.csv`, `REVIEW_TEXTS.csv` | Review sheets for the teacher |

Rules:
- **No Arabic is typed in these files.** Lessons point at Quran words by surah:ayah:word
  and the app shows the Tanzil text. The Arabic in the review sheets is copied from Tanzil
  by the script.
- `python3 tools/learn/build_learn_db.py` merges these files into
  `assets/learn/learn_content.db`. It stops on any wrong reference, a missing meaning, or
  Arabic typed into a lesson.
- With `--release` it also stops while anything is still DRAFT.
- The first draft was made by `tools/learn/draft_content.py`. That script will not
  overwrite these files (teacher edits) unless it is run with `--force`.
