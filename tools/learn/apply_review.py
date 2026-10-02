#!/usr/bin/env python3
"""Applies the teacher's filled review sheets to the কুরআন বুঝি content.

Rules (from the app owner):
  * "yes" in the teacher's OK column           -> approved as it is
  * text in the teacher's correction column     -> the teacher's text replaces the
                                                   draft and counts as approved
                                                   (no second round)
  * anything else (no, empty, only a comment)   -> stays DRAFT
Every changed item is added to content/CHANGELOG.md (old text -> new text), with
the reviewer and date. Approved items get reviewed_by = reviewer, reviewed_on = date.

A lesson leaves DRAFT when its title, goal and explanation are all approved.

Usage:
  python3 tools/learn/apply_review.py --reviewer "Name" --date 2026-10-20 \
      --sheet path/to/REVIEW_SHEET.csv --texts path/to/REVIEW_TEXTS.csv
Then rebuild: python3 tools/learn/build_learn_db.py
"""

import argparse
import csv
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
YES = {'yes', 'y', 'ok', 'হ্যাঁ', 'হ্যা', 'ঠিক', 'ঠিক আছে', '✓', '✔', 'true', '1'}
ARABIC = re.compile('[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]')


def read(path):
    with open(path, encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write(path, rows, fields):
    with open(path, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def col(row, prefix):
    """The value of the first column whose name starts with prefix."""
    for k, v in row.items():
        if k and k.strip().startswith(prefix):
            return (v or '').strip()
    return ''


def decide(ok, correction):
    """('approve' | 'correct' | 'draft', new_text)"""
    if correction:
        return 'correct', correction
    if ok.lower() in YES:
        return 'approve', None
    return 'draft', None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--reviewer', required=True)
    ap.add_argument('--date', required=True, help='YYYY-MM-DD')
    ap.add_argument('--sheet', required=True, help='filled REVIEW_SHEET.csv')
    ap.add_argument('--texts', help='filled REVIEW_TEXTS.csv')
    ap.add_argument('--content', default=str(ROOT / 'content'))
    args = ap.parse_args()
    content = pathlib.Path(args.content)
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', args.date):
        sys.exit('--date must look like 2026-10-20')

    changes, counts, problems = [], {'approve': 0, 'correct': 0, 'draft': 0}, []

    # ---- words
    lem_path = content / 'lemmas_bn.csv'
    lemmas = read(lem_path)
    by_id = {r['lemma_id']: r for r in lemmas}
    for row in read(args.sheet):
        lid = (row.get('lemma_id') or '').strip()
        if lid not in by_id:
            problems.append(f'REVIEW_SHEET: unknown lemma_id {lid!r}')
            continue
        what, new = decide(col(row, 'teacher: OK'), col(row, 'teacher: correct'))
        if new and ARABIC.search(new):
            problems.append(f'REVIEW_SHEET: lemma {lid}: correction contains Arabic; '
                            'meanings must be Bangla only (kept as DRAFT)')
            what = 'draft'
        counts[what] += 1
        r = by_id[lid]
        if what == 'draft':
            continue
        if what == 'correct' and new != r['meaning_bn']:
            changes.append(('অর্থ', f'{r["lesson"]} · lemma {lid} ({col(row, "arabic_word")})',
                            r['meaning_bn'], new, col(row, 'teacher: comment')))
            r['meaning_bn'] = new
        r['reviewed_by'], r['reviewed_on'] = args.reviewer, args.date
    write(lem_path, lemmas, list(lemmas[0].keys()))

    # ---- lesson texts and root ideas
    if args.texts:
        roots_path = content / 'roots_bn.csv'
        roots = read(roots_path)
        root_by = {r['root']: r for r in roots}
        lessons = {p.stem: (p, json.loads(p.read_text(encoding='utf-8')))
                   for p in sorted((content / 'lessons').glob('*.json'))}
        lesson_ok = {k: [] for k in lessons}
        for row in read(args.texts):
            kind, key = row['kind'].strip(), row['id'].strip()
            what, new = decide(col(row, 'teacher: OK'), col(row, 'teacher: correction'))
            if new and ARABIC.search(new):
                problems.append(f'REVIEW_TEXTS: {kind} {key}: correction contains Arabic; '
                                'refer to words by name in Bangla (kept as DRAFT)')
                what = 'draft'
            counts[what] += 1
            if kind == 'root idea':
                r = root_by.get(key)
                if r is None:
                    problems.append(f'REVIEW_TEXTS: unknown root {key}')
                    continue
                if what == 'draft':
                    continue
                if what == 'correct' and new != r['meaning_bn']:
                    changes.append(('মূল অক্ষর', key, r['meaning_bn'], new, ''))
                    r['meaning_bn'] = new
                r['reviewed_by'], r['reviewed_on'] = args.reviewer, args.date
                continue
            if key not in lessons:
                problems.append(f'REVIEW_TEXTS: unknown lesson {key}')
                continue
            _, lo = lessons[key]
            lesson_ok[key].append(what != 'draft')
            if what != 'correct':
                continue
            if kind == 'lesson title':
                old, lo['title_bn'] = lo['title_bn'], new
            elif kind == 'lesson goal':
                old, lo['objective_bn'] = lo['objective_bn'], new
            elif kind == 'explanation':
                step = next(s for s in lo['body']['steps'] if s['type'] == 'explain')
                old, step['text_bn'] = step['text_bn'], new
            else:
                problems.append(f'REVIEW_TEXTS: unknown kind {kind!r}')
                continue
            if old != new:
                changes.append((kind, key, old, new, ''))
        for key, (path, lo) in lessons.items():
            oks = lesson_ok[key]
            if len(oks) >= 3 and all(oks):
                lo['reviewed_by'], lo['reviewed_on'] = args.reviewer, args.date
            path.write_text(json.dumps(lo, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        write(roots_path, roots, list(roots[0].keys()))

    # ---- changelog
    log = content / 'CHANGELOG.md'
    lines = [] if log.exists() else ['# কুরআন বুঝি content changelog', '',
                                      'Every text changed by a teacher review, old → new.', '']
    lines += [f'## {args.date} · reviewed by {args.reviewer}', '',
              f'- Approved as written: {counts["approve"]}',
              f'- Approved with the teacher\'s correction: {counts["correct"]}',
              f'- Still DRAFT (no answer or "no"): {counts["draft"]}', '']
    if changes:
        lines += ['| What | Item | Old | New | Teacher\'s comment |', '|---|---|---|---|---|']
        for what, item, old, new, note in changes:
            cell = lambda x: x.replace('|', '/').replace('\n', ' ')  # noqa: E731
            lines.append(f'| {what} | {cell(item)} | {cell(old)} | {cell(new)} | {cell(note)} |')
        lines.append('')
    with open(log, 'a', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')

    for p in problems:
        print('WARNING', p)
    print(f'approved {counts["approve"]}, corrected {counts["correct"]}, '
          f'still DRAFT {counts["draft"]}; {len(changes)} changes logged in {log}')


if __name__ == '__main__':
    main()
