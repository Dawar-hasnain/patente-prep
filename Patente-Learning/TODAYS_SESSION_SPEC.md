# Today's Session — Spec v2 (the "Coach" update)

Status: **Phase 1 implemented.** Phases 2–4 pending.

## 1. Objective
Replace "the user decides what to study" with **one button that builds the right daily session**, so a learner who completes their daily session reaches the **"Exam ready"** band (`P(pass) ≥ 0.85`) within their chosen window. This is the feature that removes the linear/static feel — the app starts **deciding, adapting, and showing momentum** instead of just listing and scoring.

## 2. The load-bearing decision: measure readiness at the CONCEPT level
The bank is **7,142 questions but only ~716 Blocchi (concepts)** — ~10 paraphrased true/false variants per concept. Mastering a concept transfers to its variants.

- **Question-level model (old):** to clear the band you need ~95% coverage of 7,142 → ~500–700 mock tests → multi-year. "Ready in a month" is impossible.
- **Concept-level model (new):** ~716 concepts; with deliberate unseen-seeking you cover them ~10× faster. "Ready in weeks" becomes real.

This is also more truthful to how the real exam reuses questions. **Readiness is now computed over the 716 Blocchi, not the 7,142 questions.**

### Calibration (implemented)
- `ReadinessEngine.priorCorrectness`: `0.55 → 0.65` (an unseen *variant* of a partly-covered concept isn't a coin-flip).
- `evaluate()` now uses **concept coverage** and **average concept mastery**: `p = coverage·p_seen + (1−coverage)·0.65`, then `P(≤3 wrong of 30)`.
- `ReadinessReport.attemptedQuestions/totalQuestions` now carry **concept** counts. (UI labels "Questions Seen"/"Bank Covered" to be relabeled "Concepts" in the UI phase.)

### Honesty caveats
- Transfer isn't perfect (negated/trick variants get missed), so a concept needs its **two polarities** practised and is subject to spaced-repetition decay — not "one correct = mastered forever."
- The marketing claim is phrased against **Fast track + daily completion** ("ready in as little as ~3–4 weeks"), never a guarantee. The in-app forecast gives each user their real number.

## 3. The Core Set (implemented)
`BloccoStore`:
- `coreQuestionsByBlocco` — up to **2 representative questions per Blocco**, one VERO + one FALSO when both exist (both polarities), deterministic by id.
- `coreQuestions` — flat pool the session + readiness draw from.
- `chapterWeights` — per-chapter share of concepts, for **stratified** new-concept sampling (no all-one-chapter sessions).
- `conceptCount` — 716.

## 4. Tiers & session length (implemented: SessionTier)
| Tier | Daily | Format | Initial window* |
|---|---|---|---|
| **Fast track** | 50 | 2 × 25 | ~3–4 weeks |
| **Standard** | 40 | 2 × 20 | ~4–5 weeks |
| **Relaxed** | 30 | 1 × 30 | ~6 weeks |

\*Initial model estimate; the in-app number is a live forecast (§5). Default = **Fast track**.
Splitting the larger tiers keeps each sitting commute-sized and protects completion rate (the metric that decides whether the claim holds). Daily practice can exceed the real exam length; the **Mock Exam stays 30**.

## 5. Dynamic ready-date forecast (implemented: ReadinessForecaster)
The date is the home headline, so it's a **live forecast**, not a fixed day-1 promise:
- Persist `prepStartDate` (first session). *(store lands in Phase 3)*
- `ReadinessForecaster.forecast(...)` projects from **actual mastered-concept count** + tier pace + recent cadence; returns `readyDate`, `sessionsRemaining`, `onTrack`, `isReady`.
- `targetCoverage = 0.85` (master ~85% of concepts → band cleared).
- Status surfaces as "On track — ready by ~Mar 14" / "~5 days behind — ~Mar 19." Missed days slide it (gentle, honest pressure); a strong week pulls it in.

## 6. Queue-mixing algorithm (Phase 2 — pending)
Pools from the Core Set, deduped:
- **Review (due/weak):** seen core Qs with `decayedConfidence < 0.6`, worst-first. *(helper `dueOrWeakCoreIDs` implemented)*
- **New:** unseen core Qs, stratified by `chapterWeights`. *(helper `unseenCoreIDs` implemented)*

Self-balancing mix driven by coverage (not the calendar):
```
newFraction = clamp(1 − conceptCoverage, 0.2, 0.85)
newCount    = round(size · newFraction)
reviewCount = size − newCount
```
Fill review (worst-first) then new (stratified); backfill across pools; cold start = all new; full coverage = all review. **Interleave** new/review; cap consecutive same-chapter at ~3. Lives in a pure, testable `SessionBuilder`.

## 7. Spaced repetition
Reuses the existing `decayedConfidence` (full decay ~16 idle days). A concept re-enters Review when its decayed confidence drops below **0.6** — the decay curve *is* the scheduler; no separate SR engine.

## 8. Streak & split-session semantics (Phase 3 — pending)
- **Daily goal met** = all sub-sessions that day (both halves for 50/40; the block for 30). Halves can be done any time that day.
- Home mid-day state: "Set 1 of 2 done · 25 to go."
- **Streak** = consecutive days the goal was met; **missed day → reset to 0**.

## 9. UI (Phase 4 — pending)
- **Home `TodaySessionCard`** (hero): tier, today's chunk progress, streak, and the **forecast date as the headline**.
- **Runner:** reuse `TrueFalsePracticeView`'s question card (tappable sentence, Show English, VERO/FALSO, semantic haptics).
- **End-of-session summary:** score, **readiness before → after** (the momentum hit), composition ("18 new · 12 review"), streak, next action.
- **Settings tier picker:** all three tiers each showing their **live projected date**.

## 10. Reuse map
- **Reused:** `TrueFalsePracticeView`, `ExamProgressManager.record`, `ReadinessEngine`, `decayedConfidence`, `HapticsManager`.
- **Net-new:** Core Set (BloccoStore), concept-level `ExamProgressManager` helpers, `ReadinessEngine` recalibration, `ReadinessForecaster` + `SessionTier` *(done)*; `SessionBuilder` (P2), `DailySessionStore` (P3), `TodaySessionCard`/`DailySessionView`/tier picker (P4).

## 11. Success metrics
- Activation: % starting a session D1.
- Habit: sessions/week, streak distribution, **completion rate by tier** (kill metric — if Fast track < ~80%, default to Standard).
- The claim: % reaching "Exam ready" within their tier window; median days-to-ready.
- Leading: readiness slope per completed session (positive, decaying).

## 12. Build phases
1. **Calibration + Core Set + ReadinessForecaster + MockExam ≤3 fix** — ✅ implemented.
2. `SessionBuilder` (+ unit tests on mixing/backfill/cold-start).
3. `DailySessionStore` (tiers, prepStartDate, streak, split-session goal).
4. `TodaySessionCard` + `DailySessionView` + Settings tier picker.
5. Build + verify on iPhone 17 Pro Max.

## Appendix — pass rule fix
The real patente B exam passes with **≤3 errors (fails on the 4th)**. `MockExamView` previously failed on the **3rd** mistake (≤2). Fixed to fail at the 4th, aligning the mock with both `ReadinessEngine` (`maxMistakes = 3`) and the real exam.
