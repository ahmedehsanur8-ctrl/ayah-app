<!-- Copied from the Claude Doc "Ayah Reminder — Quranic Arabic Feature: Research Report + Build Spec" (https://claude.ai/code/artifact/c4f0851e-4493-4ce3-9d6d-005ad7ff3039), 2026-10-02. Link targets and some bold labels did not survive the export; the doc is the source of truth. -->

# Ayah Reminder — Quranic Arabic Feature: Research Report + Build Spec
2026-10-02 · @Ahmed

## Summary
Build "কুরআন বুঝি" (Understand the Quran) as a frequency-first, verse-anchored learning path inside Ayah Reminder, fed by the ayahs users already receive, with a 6-screen MVP of 30 lessons and about 150 words.
 Teach the highest-frequency Quran words first, always inside a real ayah, and layer only the grammar needed to read that ayah. Schedule review with FSRS (MIT-licensed Dart package). Connect it to reminders with one quiet "এই আয়াত বুঝুন" button, not a cluttered word-of-the-day panel. Bundle all text data offline; stream only audio.
 Arabic Quran text (Tanzil) is safe to bundle with attribution. Word morphology (Quranic Arabic Corpus) carries GPL plus a "non-commercial research" statement, which matters if Ayah Reminder ever charges money. A Bangla word-by-word gloss with a verified commercial license could not be found, so you should write your own Bangla glosses for the lesson vocabulary (about 150–500 words), reviewed by a teacher.
 I had no access to the Ayah Reminder repository (nothing uploaded, private GitHub repo). Every section that depends on the codebase is written as a decision rule plus an inspection checklist that Claude Code must run first (Part B, Phase 0). Nothing below assumes your state management, database or routing.
 Bangla word-by-word license (GreenTech/QuranWBW), word-audio license for audio.qurancdn.com, user sentiment from Reddit at scale, Azure/Amazon/ElevenLabs Arabic pricing as of today.

## A1. Product fit inside Ayah Reminder
The feature should live where ayahs already appear, and earn a bottom-nav slot only if it gets daily use.
 Two scheduled motivational ayahs a day, shown full-screen in Arabic + Bangla with a short note; prayer times with azan; Arabic recitation and a Bangla AI voice; a full Quran with Zakaria and other Bangla translations is planned, plus a mood section, duas and tasbih. The user is a Bangla-speaking Muslim who can recite Arabic but reads the meaning in Bangla.
 The full-screen reminder is the strongest moment the app owns: the user is already looking at an ayah. The learning feature should turn that moment from "read the Bangla" into "recognise a few Arabic words yourself". That is the difference between a reminder app that teaches and Duolingo with ayahs.

- If the bottom nav has 4 or fewer items: add a 5th tab, শিখুন (Learn).
- If it already has 5: put Learn as a large card on the Home screen and inside the Quran reader, not a new tab. Android guidance caps bottom navigation at 3–5 destinations.
- Either way, the entry from the reminder screen matters more than the tab.
 (a straight run, so a numbered list):
- Reminder: the ayah appears as usual. Nothing new is added on top of it.
- Understand: one small button under the ayah, "এই আয়াত বুঝুন". It opens the ayah with tappable words.
- Learn: tapping a word shows meaning, root, how often it appears, and "শিখব" (add to review).
- Review: added words enter the FSRS queue; a short daily review (3–5 min) is offered once a day, not at reminder time.
- Remember: the next reminder highlights words the user already knows, in a subtle colour. Seeing "I know 4 of these 9 words" is the reward.
 Yes, because each step uses a habit the app already has (the reminder) and gives back something visible (known words highlighted in the next ayah). The risk is clutter on a devotional screen; keep the reminder itself unchanged and make the learning layer opt-in from one button.
 Pick the word automatically: the highest-frequency content word in that ayah that the user has not yet learned. Show it on the reminder only if the user has turned on "শেখার মোড" (learning mode) in settings; default off for existing users, on for users who started the course. A notification-level "word of the day" separate from ayahs would compete with the reminders and is not recommended for MVP.

## A2. Data sources and licensing
Only two sources are clearly safe to bundle today: Tanzil Arabic text and the MIT-licensed FSRS code; morphology is usable with care; Bangla word glosses must be written in-house or licensed by email.
| Resource | Gives you | License as published | Commercial | Modify | Bundle offline | Attribution | Category | Verdict |
|---|---|---|---|---|---|---|---|---|
|  | Uthmani / simple Arabic text, verse-level | CC BY 3.0 with a no-changes clause; usable in any app if Tanzil is credited and linked | Yes | No (verbatim only) | Yes | "Tanzil.net" + link, keep notice | A | Use for all Arabic text |
|  | Segments, POS, root, lemma, case, mood, verb form; treebank for ~40% of words | GNU GPL "with terms of use"; the  also asks that data not be used commercially | Conflicting | Yes (GPL) | Yes, with notice | Credit + link required | A, with a flag | Use while the app is free; get written permission before any paid tier |
|  | Verified text, metadata, QAC morphology, i'rab | Own data free to use, no attribution required; morphology stays GPL, i'rab treebank is MIT | Yes (own data) | Yes | Yes | Link appreciated; QAC + link required for morphology | A | Good second source for syntax (MIT treebank) |
|  | QAC + Tanzil converted to TF format | CC BY 4.0 for the data | Yes as stated | Yes | Yes | Credit | A, derived | Still inherits Tanzil's no-changes clause and QAC terms; treat as QAC |
|  | Scripts, fonts, word-by-word translations (incl. Bangla), morphology, recitations with word timestamps | Varies per resource; FAQ says commercial use is allowed but each resource has its own terms | Per resource | Per resource | Yes (download, no API) | Per resource | A/E mix | Check each file's license page before use |
| Bangla word-by-word (GreenTech, used by  and ) | Bangla gloss per Quran word | Could not verify | Unknown | Unknown | Unknown | Unknown | E | Do not bundle; email GreenTech for written permission |
|  | Text, translations, tafsir, audio | Developer terms; content may not be cached beyond 1 week unless it is in the Content Sync set or QF permits | Per terms | No | No (1-week cap) | Required | C/D | Online-only enrichment, not the learning core |
|  | Full murattal recitations | Free general use granted for apps, websites, public and private sector | Yes | Not stated | Yes | Not stated (credit anyway) | B-like grant | Use for ayah audio |
| Word audio on audio.qurancdn.com () | Single-word pronunciation | Docs say it is a public CDN asset but point to QF terms for storage/redistribution | Could not verify | No | Could not verify | Required | E | Stream only, never bundle, until confirmed |
|  | Spaced-repetition scheduler | MIT | Yes | Yes | Yes | Keep license text | A | Use |
|  | REST API for text + audio | Text free for non-commercial use; commercial reuse asks for acknowledgement; text must not be altered | Yes with credit | No | Yes | Credit | C | Fine as a fallback, not needed |
| Understand Quran Academy, Bayyinah, Quranic app, YouTube courses | Curricula, books, videos | Copyrighted | No | No | No | — | C | Inspiration and links only |

 A open-licensed, B public-domain-like grant, C free but copyrighted, D link/embed only, E unclear (do not use).
 Bundle Tanzil text and a QAC-derived word table (surah, ayah, word index, segment, lemma, root, POS, features). Write Bangla glosses yourself for the curriculum words; for every other word in an ayah, show the English QAC gloss only if you choose to, or show nothing and let the user add it later. Free does not mean copyable: none of the Bangla courses found grant reuse.

## A3. Competitive landscape and the Bangla gap
Every serious Quranic-Arabic product converges on the same recipe (frequent words first, real verses, spaced repetition); the open gap is doing it in Bangla, attached to a habit the user already has.
| Product | Approach | Language | What to learn from it |
|---|---|---|---|
|  | Teaches 125 words through Fatiha, short surahs and salah; claims they cover about 40,000 of ~77,800 words | Many (books) | Start from what people already recite daily |
|  | Most-common words first, bite-sized lessons, spaced repetition, verses as material | English | Short sessions; reviews praise the game feel |
|  | Frequent words + basic grammar, translate verses, personal word list, timed word pop-ups | English, Urdu | Warns learners not to rush through word lists without breaking sentences down |
|  | Sarf-centred; tap words in verses and videos to add them to SRS | English | "Tap a word → add to review" is now a standard pattern |
|  | Reader with Bangla word-by-word, roots, dictionary | Bangla + others | Bangla WBW exists as reference, not as a course |
|  | Arabic grammar books in Bangla, with homework and Arabic TTS | Bangla | Proves demand; app is a book viewer with a 1-star rating from 1 review |
|  and similar | Makhraj, harakat, Noorani reading | Bangla | Bangla market is crowded at "read", thin at "understand" |

 (pattern across the products above and their own warnings; Reddit evidence could not be verified at scale in this pass): memorising word lists without being able to use them in a verse; grammar that arrives as Arabic terminology before the learner needs it; losing momentum after week 2; and translation dependency when transliteration is always shown.
 Explanations in plain Bangla, Arabic grammar terms introduced once with Bangla equivalents (ইসম = বিশেষ্য-জাতীয় শব্দ, ফি'ল = ক্রিয়া, হারফ = অব্যয়), examples drawn from what Bangladeshi Muslims recite in salah, and no reliance on English.

## A4. Learning method: hybrid, frequency-first, verse-anchored
Recommend a hybrid: learn the most frequent words inside familiar ayahs, add only the grammar each ayah needs, and review by retrieval on an expanding schedule.

- Retrieval beats rereading. In , students who were tested on a passage remembered more a week later than students who reread it, even though rereading looked better after 5 minutes. So every lesson ends in recall, not a summary screen.
- Spacing should expand. , with over 1,350 learners, found the best review gap grows with how long you want to remember: about 20–40% of the retention period for a week, about 5–10% for a year. A  adds that reviewing too soon hurts more than reviewing a bit late. Fixed 1-2-4-7-14-30 day intervals are a fair approximation; an adaptive scheduler is better.
- Quran vocabulary is concentrated. Understand Quran Academy's materials claim 125 words cover about 50% of running text, and a separate list of theirs covers 82.6% (). These counts include particles and all forms of a word. Recompute coverage yourself from QAC lemmas before putting any percentage in the app.
 for a reader who recites but does not understand, 5–15 minutes a day:
| Approach | Strength | Weakness | Verdict |
|---|---|---|---|
| Vocabulary-first | Fast visible progress | Word lists without sentences don't transfer | Core, but never alone |
| Grammar-first (classical Nahu → Sarf) | Deep and correct | Slow, high dropout for 10-minute learners | Later levels only |
| Verse-first | Most motivating, spiritual payoff | Random vocabulary, no system | Use as the frame for every lesson |
| Word frequency | Maximum coverage per minute | Needs context to stick | Decides lesson order |
| Root-based | Multiplies vocabulary (one root, many words) | Abstract for absolute beginners | Introduce from Level 3 |
|  | Frequency decides what, verses decide where, grammar arrives when needed | Needs careful authoring | Use |

 Your learners already read Arabic script, so Bangla transliteration is unnecessary in most cases and would build the wrong habit (Arabic → Bangla letters → meaning). Show it only on tap, only in Level 1, and hide it by default from Level 2.

## A5. Curriculum
Eight levels, about 125 lessons and 500 lemmas, taking a 10-minute-a-day learner roughly 9–12 months; the MVP ships Levels 1–3 (30 lessons, ~150 words).
| Level | Bangla title | Goal | Lessons | New lemmas | Grammar introduced | Est. time at 10 min/day |
|---|---|---|---|---|---|---|
| 1 | যা প্রতিদিন পড়ি | Understand Fatiha, salah phrases, 3 short surahs | 10 | ~55 | ال, و, ب/ل as prefixes; adjective after noun | 2–3 weeks |
| 2 | সর্বনাম ও ছোট বাক্য | Read nominal sentences with pronouns, particles, negation | 10 | ~50 | Pronouns, prepositions, demonstratives, nominal sentence, إنّ | 3 weeks |
| 3 | ক্রিয়ার শুরু | Recognise past, present and command verbs; first roots | 10 | ~45 | Past/present/command, subject endings, root idea | 3 weeks |
| 4 | নাহুর ভিত্তি | Idafa, cases by ending, verbal sentence order | 15 | ~60 | মুযাফ-মুযাফ ইলাইহি, i'rab endings (rafa/nasb/jarr) | 5 weeks |
| 5 | সরফের ভিত্তি | Verb forms I–X by pattern, participles, masdar | 20 | ~80 | Forms II–X, ism fa'il / maf'ul, masdar | 7 weeks |
| 6 | আয়াত বিশ্লেষণ | Break down full ayahs from Juz 30 and key passages | 25 | ~120 | Applied: relative clauses, conditionals, kana and its sisters | 9 weeks |
| 7 | শুনে বুঝি | Recognise known words in recitation without text | 15 | ~50 | Listening only | 5 weeks |
| 8 | আধুনিক আরবির সেতু | Map Quranic words to Modern Standard Arabic usage | 20 | ~60 | MSA differences, everyday phrases | 7 weeks |

 Within each level, lesson order follows frequency rank of lemmas (computed from QAC), broken only to keep each lesson inside one well-known ayah or salah phrase.

### First 30 lessons (MVP)
All Arabic below must be checked against Tanzil text and by the teacher before shipping (see A7). Time includes review.
| # | Bangla title | Objective | Vocabulary | Grammar | Quran example | Exercise | Min |
|---|---|---|---|---|---|---|---|
| 1 | বিসমিল্লাহর অর্থ | Know every word of Bismillah | بِسْم، اللّٰه، الرَّحْمٰن، الرَّحِيم | ب = দিয়ে/নামে (prefix, no term yet) | 1:1 | Tap word → meaning | 8 |
| 2 | সব প্রশংসা আল্লাহর | Read 1:2 alone | الْحَمْد، لِ، رَبّ، الْعَالَمِين | ال = নির্দিষ্ট করে | 1:2 | Match Arabic ↔ Bangla | 8 |
| 3 | বিচার দিনের মালিক | Two nouns side by side = "of" | مَالِك، يَوْم، الدِّين | Idafa felt, not named | 1:4 | Order the words | 8 |
| 4 | শুধু তোমারই ইবাদত | "We" inside a verb | إِيَّاكَ، نَعْبُدُ، نَسْتَعِينُ، وَ | ن at the start = আমরা | 1:5 | Fill the gap | 10 |
| 5 | সরল পথ দেখাও | Adjective follows noun | اهْدِ، ـنَا، الصِّرَاط، الْمُسْتَقِيم | Noun + adjective agree in ال | 1:6 | Pick the adjective | 10 |
| 6 | যাদের প্রতি অনুগ্রহ | Relative "who" | الَّذِين، أَنْعَمْتَ، عَلَى، غَيْر، لَا | الَّذِين = যারা | 1:7 | Meaning of each word | 10 |
| 7 | পুরো ফাতিহা বুঝি | Understand Fatiha without translation | Review | — | Surah 1 | Read-through, tap only unknowns | 10 |
| 8 | সালাতের শব্দ | Know the takbir and tasbih words | أَكْبَر، سُبْحَان، عَظِيم، أَعْلَى، سَبِّحْ | Comparative أَفْعَل (felt) | 87:1 | Listen → choose meaning | 10 |
| 9 | সূরা ইখলাস | Understand surah 112 | قُلْ، هُوَ، أَحَد، الصَّمَد، لَمْ، يَلِدْ، كُفُوًا | قُلْ = বলো (command, felt) | Surah 112 | Ayah word order | 10 |
| 10 | সূরা আসর | Understand surah 103; Level 1 test | الْعَصْر، إِنَّ، الْإِنْسَان، خُسْر، إِلَّا، آمَنُوا، عَمِلُوا، الصَّالِحَات، الْحَقّ، الصَّبْر | إِنَّ = নিশ্চয়ই | Surah 103 | Checkpoint quiz (15 items) | 12 |
| 11 | কোথা থেকে, কোথায় | Core prepositions | مِنْ، فِي، إِلَى، عَنْ، بِ | হারফে জার: noun after it changes ending | 2:2, 2:5 | Choose the preposition | 10 |
| 12 | সে, তারা, তুমি | Separate pronouns | هُوَ، هِيَ، هُمْ، أَنْتَ، أَنْتُمْ، أَنَا، نَحْنُ | Pronoun table (7 forms only) | 112:1, 2:5 | Pronoun ↔ Bangla | 10 |
| 13 | তোমার রব, তাদের রব | Attached pronouns | ـهُ، ـهُمْ، ـكَ، ـكُمْ، ـنَا، ـي | Pronoun glued to a noun = possessive | 1:6, 2:5, 2:21 | Split word into parts | 12 |
| 14 | এটা, ওটা | Demonstratives | هٰذَا، هٰذِهِ، ذٰلِكَ، تِلْكَ، أُولٰئِكَ | Near vs far | 2:2, 2:5 | Pick near/far | 10 |
| 15 | ছোট বাক্য: "এটা কিতাব" | Nominal sentence | كِتَاب، هُدًى، الْمُتَّقِين، رَيْب | মুবতাদা + খবর in Bangla words | 2:2 | Build the sentence | 12 |
| 16 | প্রশ্নের শব্দ | Question words | مَنْ، مَا، مَاذَا، كَيْفَ، هَلْ | Question at the front | 88:1, 101:3 | Translate the question | 10 |
| 17 | না, কখনো না | Negation | لَا، مَا، لَمْ، لَنْ، لَيْسَ | Which negative for which time | 2:2, 112:3 | Match negative to meaning | 12 |
| 18 | নিশ্চয়ই আল্লাহ সক্ষম | Emphasis particles | إِنَّ، أَنَّ، قَدْ، إِنَّمَا، كُلّ، شَيْء، قَدِير | إنّ + noun | 2:20 | Find the emphasis | 12 |
| 19 | আল্লাহর গুণ | Divine attribute words | عَلِيم، حَكِيم، غَفُور، سَمِيع، بَصِير | Pattern فَعِيل / فَعُول (felt) | 2:173 ending | Pattern spotting | 12 |
| 20 | আয়াত ২:২–২:৫ | Read four ayahs with support; Level 2 test | Review + يُقِيمُونَ، الصَّلَاة، رَزَقْنَا، يُنْفِقُونَ | — | 2:2–2:5 | Verse breakdown + checkpoint | 15 |
| 21 | সে করল | Past tense, 3rd person | كَانَ، قَالَ، جَعَلَ، خَلَقَ | Past = ফি'ল মাযী | 96:2, 2:30 | Tense spotting | 12 |
| 22 | কে করল? | Past-tense endings | قَالُوا، قُلْتَ، قُلْنَا، آمَنُوا | Ending tells the doer | 2:11, 2:13 | Who did it? | 12 |
| 23 | সে করে / করবে | Present tense | يَعْلَمُ، يَقُولُ، يُؤْمِنُونَ، يَعْبُدُ | ي/ت/ن/أ prefix = doer | 2:3 | Prefix → doer | 12 |
| 24 | আদেশ | Command form | اعْبُدُوا، اتَّقُوا، ادْعُوا، يَا أَيُّهَا | Command = আমর | 2:21 | Command or not? | 12 |
| 25 | ঈমান ও আমল | Faith vocabulary | آمَنَ، كَفَرَ، الْجَنَّة، النَّار، أَجْر | — | 103:3, 2:25 | Opposite pairs | 12 |
| 26 | জ্ঞানের শব্দ | One root, several words | عَلِمَ، عِلْم، يَعْلَمُونَ، أَعْلَم | Root shared across words | 2:13, 96:5 | Group by root | 12 |
| 27 | মূল অক্ষর চিনি | Root as a tool | كَتَبَ، كِتَاب، كُتِبَ | 3-letter root idea | 2:183 | Find the root letters | 12 |
| 28 | মানুষ, আকাশ, পৃথিবী | Creation vocabulary | النَّاس، الْأَرْض، السَّمَاء، السَّمٰوَات، قَوْم | Plural shapes (felt) | 2:21, 2:22 | Singular ↔ plural | 12 |
| 29 | দুনিয়া ও আখিরাত | Time words | الدُّنْيَا، الْآخِرَة، قَبْل، بَعْد، يَوْمَئِذٍ | — | 2:4, 99:4 | Fill the gap | 12 |
| 30 | আয়াতুল কুরসি (প্রথম অংশ) | Apply Levels 1–3 to 2:255; Level 3 test | Review + حَيّ، قَيُّوم، نَوْم | — | 2:255 | Full verse breakdown + checkpoint | 15 |

 about 160 lemma entries, of which roughly 20 are particles or pronouns. A lemma can appear in several forms; the vocabulary table stores lemmas and links forms through QAC.

## A6. Lesson design, review, motivation, audio, Bangla UX
Each lesson is 8–15 minutes in six steps that start and end in the ayah, with recall built in and review scheduled automatically.
 Your draft put the ayah second; moving it first gives meaning before memorising, and ending in the same ayah shows the payoff.
- আয়াত (2 min): the ayah in Uthmani script with recitation. Bangla meaning hidden behind a tap.
- শব্দ (3 min): 4–7 new words, one card each: Arabic large, Bangla meaning, recitation clip of that word, one-line note. Transliteration on tap, Level 1 only.
- বুঝি (1–2 min): one grammar idea in 2–4 plain Bangla sentences with one example. Arabic terms appear in brackets once.
- অনুশীলন (2–3 min): 6–10 mixed items: Arabic → Bangla choice, listen → choose, split a word into parts, put words in order.
- মনে করি (1–2 min): recall without choices: see Arabic, think of the meaning, reveal, self-rate (ভুলে গেছি / কষ্টে / মনে আছে / সহজ). This is the retrieval step and feeds FSRS.
- আবার আয়াত (1 min): the opening ayah again with learned words highlighted and a count ("৭টি শব্দের ৫টি চিনেছেন").
 Use the  (MIT) with default parameters; it adapts intervals from the user's own ratings, matching Cepeda's finding that gaps should expand. Settings for MVP: desired retention 0.90; new words come only from lessons or "শিখব" taps; daily review capped at 30 cards and about 5 minutes; if more are due, show the most overdue first and carry the rest. Map ratings: wrong answer in a choice item = Again; correct after a hint = Hard; correct = Good; user taps Easy only on recall cards. Fallback if FSRS is rejected: fixed ladder 1, 3, 7, 16, 35, 80 days, reset to 1 on Again.
 multiple choice (Arabic → Bangla, Bangla → Arabic), listen → choose, word split (prefix / word / attached pronoun), word order, and recall self-rate. Distractors are other words from the same or earlier lessons, never invented meanings.

| Use | Avoid |
|---|---|
| Daily goal in minutes (5 / 10 / 15), chosen by the user | Points or XP attached to ayahs or Allah's names |
| A gentle streak ("১২ দিন") with one free rest day a week, no loss animation | Leaderboards and comparing people |
| Words-known count and "% of Fatiha / Juz 30 you can recognise" | Coins, lives, hearts, loot, sounds of winning on Quran text |
| Level completion with a short dua or ayah, not a trophy | Push messages that guilt the user about a broken streak |

The progress that matters is "how much of what I recite do I understand"; make that the headline number.

- Ayah recitation: King Fahd Complex recordings are granted for free use in apps (). Reuse whatever source the app already plays if its license is confirmed.
- Word pronunciation: use a human reciter clip, never TTS, for any Quranic word. Option A: cut word clips from a licensed recitation using QUL word timestamps (check that timestamp file's license). Option B: stream audio.qurancdn.com word files online-only until their terms are confirmed.
- TTS: allowed only for Bangla explanations (you already chose ElevenLabs for the Bangla voice) and for Level 8 MSA examples.  offers Arabic voices; WaveNet is listed at about $4 per million characters and Chirp 3 HD at about $30 per million, each after a monthly free tier (Google's pages disagree on whether WaveNet's free tier is 1 or 4 million characters; check the console). Microsoft, Amazon and open-source Arabic TTS pricing and quality were not re-verified in this pass. Pre-generate audio and ship files; do not call TTS at runtime.

- App UI stays LTR Bangla. Arabic runs sit in their own widgets with TextDirection.rtl; never mix Arabic and Bangla in one Text line except a single bracketed term.
- Fonts: keep whatever Uthmani font the app already uses for ayahs; Arabic in lessons at least 1.6× the Bangla size; Bangla line height about 1.5 so matras don't clip.
- Word highlighting needs word-level Arabic segments, not one string per ayah; this is why the QuranWord table exists.
- Transliteration: Bangla script, on tap, Level 1 only, off by default afterwards.
- Use Bangla numerals in UI copy (১২ দিন) and Arabic numbers in references only if the rest of the app does.

## A7. Content production, AI, monetization, metrics, risks
You must write the Bangla layer yourselves, and a qualified Arabic/Quran teacher must sign off every Bangla meaning and grammar explanation before release.

| From datasets (verify, don't edit) | Written by you (reviewed) |
|---|---|
| Arabic Quran text (Tanzil) | Bangla meaning per lemma, in context |
| Word segmentation, lemma, root, POS, features (QAC) | Lesson titles, objectives, grammar explanations in Bangla |
| Frequency counts (computed from QAC) | Exercise items and distractor selection rules |
| Ayah recitation audio (licensed source) | Ayah choice per lesson, "why this matters" notes |
| Word timestamps (QUL, if license allows) | Level checkpoints, onboarding copy |

 (straight run):
- Research: pick lemmas by frequency, pick the anchor ayah.
- Draft: Bangla glosses and explanation (AI may draft, see below).
- Arabic verification: every Arabic string pulled from Tanzil by reference, never typed or AI-generated.
- Bangla review: a Bangla editor for clarity and register.
- Quran reference check: script confirms each surah:ayah:word index exists and matches.
-  a qualified Arabic/Quran teacher approves meanings, grammar labels and any note touching interpretation. Record reviewer name and date per lesson.
- QA: in-app test on a low-end Android phone and on your Oppo.
- Publish: lesson JSON version bump; content ships as a bundled asset update.
 Safe with human check: drafting simple Bangla explanations from teacher notes, generating quiz items from verified data, varying example sentences from already-approved vocabulary, suggesting distractors. Not allowed without a teacher's verification: any Quran meaning, any grammatical analysis (i'rab), any tafsir-like note, any ruling. AI must never produce Arabic Quran text; the app always pulls it by reference.
 If Ayah Reminder is free today, keep all lessons, review and Quran integration free forever. If you later add premium, limit it to conveniences: offline audio packs for all reciters, extra themes, advanced statistics, export. Two cautions: QAC's FAQ asks for non-commercial use, so get written permission before any paid tier; and Quran Foundation API content cannot be cached offline beyond one week regardless.

| Metric | Definition | Early target |
|---|---|---|
| Activation | % of weekly users who finish Lesson 1 | 15% |
| Reminder → learn rate | % of reminder views where "এই আয়াত বুঝুন" is tapped | 3–5% |
| Lesson completion | Finished ÷ started per lesson | 75% |
| Review adherence | Days with due cards reviewed ÷ days with due cards | 50% |
| Retained words | Cards with stability ≥ 21 days | Grows weekly |
| Recognition in context | % of words in today's reminder ayah the user knows | Headline in-app number |
| D7 / D30 retention of learners | Learners active again on day 7 / 30 | 35% / 20% |

Targets are starting guesses to calibrate, not benchmarks.

- Licensing: QAC non-commercial wording; unverified Bangla WBW. Mitigation: own glosses, permission emails, attribution screen.
- Accuracy: a wrong Quran meaning is a serious harm. Mitigation: teacher sign-off logged per lesson, report-an-error button on every word.
- Clutter: the devotional reminder becomes a classroom. Mitigation: one button, learning mode off by default.
- Scope: you are building alone with Claude Code. Mitigation: MVP = Levels 1–3 only; Levels 4–8 are content work, not code.
- App size: full QAC word table is large. Mitigation: ship a compressed SQLite asset; measure before deciding.

## Part B. Build this in Ayah Reminder (spec for Claude Code)
Paste this section into Claude Code with: "Build the Quranic Arabic learning feature according to the research specification. Do Phase 0 first and report back before writing feature code."

### Phase 0 — Inspect, then report (no feature code)
Produce a short docs/learn_arabic_inventory.md answering each item with file paths:
- Flutter / Dart versions (pubspec.yaml, flutter --version), Android minSdk
- Folder architecture (feature-first? layers?) and state management in use (Provider, Riverpod, Bloc, GetX, setState)
- Router (Navigator 1, go_router, auto_route) and the bottom-nav widget + its item count
- Theme: ThemeData file, colour constants, Arabic font, Bangla font, card/button widgets to reuse
- Local storage: sqflite / drift / isar / hive / shared_preferences; existing tables and migrations
- How ayahs are stored: per-ayah strings or per-word? Which Quran text source and its license notice
- Audio package (just_audio / audioplayers) and current recitation source
- Notification + full-screen reminder implementation and the screen that renders the ayah
- Bookmarks / favourites, progress, settings storage
- Analytics SDK, if any; auth or user profile, if any
- Localization setup (intl/ARB or hard-coded Bangla)
Rules: reuse every existing equivalent; add at most two new packages (fsrs, and a SQLite package only if none exists). Match the app's existing state-management pattern exactly.

### MVP scope (exactly this)
In: 6 screens below, 30 lessons (Levels 1–3), ~160 lemmas, FSRS review, "এই আয়াত বুঝুন" from the reminder, word sheet with "শিখব", progress screen, attribution screen. Out: Levels 4–8, listening drills, Word of the Ayah card, verse-breakdown grammar table, accounts/sync, AI tutor, speaking.

### Navigation
- Bottom nav has ≤ 4 items → add tab শিখুন (icon: open book). Otherwise → Home card "কুরআন বুঝি" + entry in drawer/settings.
- Routes: /learn (dashboard), /learn/path, /learn/lesson/:id, /learn/review, /learn/words, /learn/progress, /learn/ayah/:surah/:ayah (tappable ayah), /learn/credits.
- Reminder screen: add one text button below the Bangla meaning, label এই আয়াত বুঝুন, opening /learn/ayah/:s/:a. Do not change anything else on that screen.

### Screens
| Screen | Contents | Key components |
|---|---|---|
| Dashboard /learn | Continue card (next lesson title + minutes), Today card ("রিভিউ: ১২টি · ৫ মিনিট"), words-known count, streak, link to path | ContinueLessonCard, DailyReviewCard, StatChip |
| Path /learn/path | Levels 1–3 as sections, lessons as rows: locked / available / done with score | LevelSection, LessonTile |
| Lesson /learn/lesson/:id | 6 steps from A6 as a PageView with a top progress bar; back = confirm exit | AyahBlock, WordCard, ExplainCard, QuizItem, RecallCard, AyahRecapBlock |
| Review /learn/review | Due cards, recall + 4 rating buttons, finishes with count summary | RecallCard, RatingBar |
| Words /learn/words | All learned lemmas, search Arabic/Bangla, filter by level; tap → word sheet | WordListTile, WordSheet |
| Progress /learn/progress | Words known, % recognisable in Fatiha and Juz 30, 30-day activity, level badges | CoverageRing, ActivityGrid |
| Tappable ayah /learn/ayah/:s/:a | Ayah split into words; known words tinted; tap → WordSheet | TappableAyah, WordSheet |
| Credits /learn/credits | Tanzil, QAC, audio source, FSRS license text | static |

WordSheet (bottom sheet): Arabic word large, Bangla meaning (if authored) or "অর্থ এখনো যোগ হয়নি", root letters spaced (ر ح م), occurrences count, play word audio, button শিখব (adds card) or "রিভিউতে আছে", and "ভুল জানান" (report error).

### Data
Two stores: a read-only bundled content DB (assets/learn/learn_content.db, replaced on app update) and the user DB (existing app DB, new tables via migration).
```sql
-- CONTENT DB (bundled, read-only)
CREATE TABLE quran_word (
  id INTEGER PRIMARY KEY,           -- global word id
  surah INTEGER, ayah INTEGER, word_index INTEGER,
  text_uthmani TEXT,                -- from Tanzil, verbatim
  lemma_id INTEGER, root TEXT,      -- from QAC
  pos TEXT, features TEXT,          -- QAC tags as stored
  UNIQUE (surah, ayah, word_index));
CREATE TABLE lemma (
  id INTEGER PRIMARY KEY, lemma_ar TEXT, root TEXT,
  pos TEXT, frequency INTEGER,      -- computed from quran_word
  meaning_bn TEXT,                  -- authored; NULL if not yet written
  translit_bn TEXT, note_bn TEXT,
  audio_key TEXT, reviewed_by TEXT, reviewed_on TEXT);
CREATE TABLE lesson (
  id TEXT PRIMARY KEY,              -- 'L1-01'
  level INTEGER, ord INTEGER, title_bn TEXT, objective_bn TEXT,
  minutes INTEGER, anchor_surah INTEGER, anchor_ayah_from INTEGER, anchor_ayah_to INTEGER,
  body_json TEXT,                   -- steps, explanation, quiz items
  content_version INTEGER);
CREATE TABLE lesson_lemma (lesson_id TEXT, lemma_id INTEGER, ord INTEGER,
  PRIMARY KEY (lesson_id, lemma_id));

-- USER DB (migration in existing app DB)
CREATE TABLE learn_card (
  lemma_id INTEGER PRIMARY KEY, source TEXT,       -- 'lesson' | 'ayah_tap'
  fsrs_json TEXT,                                   -- serialized fsrs Card
  due_utc TEXT, created_utc TEXT);
CREATE TABLE learn_review_log (
  id INTEGER PRIMARY KEY, lemma_id INTEGER, rating INTEGER,
  reviewed_utc TEXT, elapsed_ms INTEGER);
CREATE TABLE learn_lesson_progress (
  lesson_id TEXT PRIMARY KEY, status TEXT,          -- locked|available|done
  best_score INTEGER, completed_utc TEXT);
CREATE TABLE learn_settings (key TEXT PRIMARY KEY, value TEXT);
  -- daily_goal_min, learning_mode_on, show_translit, streak_*
```
No userId column: the app has no accounts (confirm in Phase 0). Add it only if Phase 0 finds auth.
body_json
```json
{
  "steps": [
    {"type": "ayah", "surah": 1, "ayah": 2},
    {"type": "words", "lemma_ids": [101, 102, 103, 104]},
    {"type": "explain", "text_bn": "...", "example": {"surah": 1, "ayah": 2, "word_index": 1}},
    {"type": "quiz", "items": [
      {"kind": "mcq_ar_bn", "lemma_id": 101, "distractor_ids": [5, 9, 12]},
      {"kind": "listen_choose", "lemma_id": 103, "distractor_ids": [101, 104, 7]},
      {"kind": "split", "surah": 1, "ayah": 2, "word_index": 2},
      {"kind": "order", "surah": 1, "ayah": 2}]},
    {"type": "recall", "lemma_ids": [101, 102, 103, 104]},
    {"type": "ayah_recap", "surah": 1, "ayah": 2}
  ]
}
```
Arabic never appears inside lesson JSON; it is always looked up by reference from quran_word.
tool/ download Tanzil Uthmani text and QAC morphology v0.4 → align QAC segments to Tanzil word indices → compute lemma frequency → merge content/lemmas_bn.csv and content/lessons/*.json (authored) → validate every reference and every lesson's lemma has meaning_bn and reviewed_by → write learn_content.db. Fail the build on any missing reference.

### Code structure (adapt to Phase 0 findings)
```
lib/features/learn/
  data/   content_repository.dart  (read-only content DB)
          progress_repository.dart (user tables)
  domain/ lemma.dart, quran_word.dart, lesson.dart, learn_card.dart
  srs/    srs_service.dart         (wraps package:fsrs)
  audio/  word_audio_service.dart  (wraps existing audio player)
  state/  <same pattern as app: provider/bloc/riverpod>
  ui/     screens/..., widgets/...
```

### Spaced repetition
SrsService: addCard(lemmaId, source), dueCards(limit: 30), review(lemmaId, Rating), stats(). Use FSRS defaults, desired retention 0.90, all times UTC (the package is UTC-only). Lesson completion adds its lemmas as new cards rated once by the recall step. Daily cap 30 reviews; overdue first.

### Audio
- Ayah audio: existing player and source. Word audio: WordAudioService.play(surah, ayah, wordIndex) → online stream from the confirmed source, cached in app cache dir (not bundled) until a bundling license is confirmed. Offline with no cache → disable the play button with a tooltip, never error.
- No TTS for Arabic Quranic words.

### Offline behaviour
| Bundled (works offline) | Downloaded on demand | Online only |
|---|---|---|
| Content DB: text, morphology, lessons, Bangla meanings | Word audio cache, extra reciters | Error reports, analytics upload, content-version check |
| All progress and reviews |  |  |

Target content DB size under 15 MB compressed; measure after the pipeline runs and report.

### Quran integration
- Reminder screen: এই আয়াত বুঝুন button (always) → tappable ayah.
- If learning_mode_on: tint known words in the reminder ayah and show "৯টি শব্দের ৪টি চেনেন". Default off; turned on automatically when the user finishes Lesson 1, with a toggle in Learn settings.
- Full Quran reader (when built): long-press a word → WordSheet.

### Analytics events (only if the app has analytics; otherwise store counts locally)
learn_open, lesson_start {id}, lesson_complete {id, score, secs}, review_session {count, secs}, ayah_learn_tap {surah, ayah}, word_add {lemma_id, source}, error_report {lemma_id}. No ayah text or free text in events.

### Localization, RTL, accessibility
- All UI strings Bangla, via the app's existing localization method; no English fallback visible.
- Arabic widgets: Directionality(textDirection: TextDirection.rtl), existing Uthmani font, min 26sp in lessons; Bangla min 16sp, line height 1.5.
- Respect system text scaling up to 1.6× without overflow; test at 1.3× on a 360dp-wide screen.
- Semantics labels in Bangla for every button; audio buttons announce "শব্দ শুনুন". Colour is never the only signal for known words (add an underline).
- Touch targets ≥ 48dp; rating buttons full-width on small phones.

### Acceptance checks
- Phase 0 inventory written and reviewed before feature code
- All 30 lessons load offline in airplane mode
- Every Arabic string in the UI comes from quran_word by reference
- Reminder screen unchanged except one button
- Review queue survives app kill and device reboot; due dates correct across timezone change
- Credits screen shows Tanzil notice + link, QAC credit + link, audio source, FSRS MIT text

### V2 (after MVP retention data)
Levels 4–6 content; verse breakdown with a word table and a 2–3 sentence Bangla structure note (grammar labels from QAC/treebank, simplified); Word of the Ayah card under learning mode; root explorer (all Quran words from one root); listening drills (Level 7) using word timestamps; Juz 30 coverage map.

### V3 (only if V2 retention justifies it)
Level 8 MSA bridge; optional AI explainer that only rephrases teacher-approved content and refuses interpretation; pronunciation feedback only if a licensed Quran-recitation recognition model is available; account + sync. Conversational Arabic and an open-ended AI tutor are not recommended: they move away from the app's purpose and raise accuracy risk.

## Sources
Licensing and data
-  · 
-  · 
- 
- 
-  ·  · 
-  · 
- 
- 
- 
- 
- 
Learning research
-  · 
- 
-  · 
Products
-  ·  ·  ·  ·  · 
 Bangla word-by-word license; word-audio bundling rights on audio.qurancdn.com; Reddit/community sentiment at scale; Microsoft, Amazon, ElevenLabs and open-source Arabic TTS pricing and quality; Bayyinah and Tarteel learning-feature details; the Ayah Reminder codebase itself.
