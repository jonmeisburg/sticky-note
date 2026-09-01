# Code review findings — ticket 02 (editing + autosave)

**Review:** two-axis (Standards + Spec), fresh session, against commits `0e33c0e..6968cda` (the four unpushed ticket-02 commits: f4dcc46, 5d21ed0, e277151, 6968cda) and the amended spec.
**Spec source:** `.scratch/sticky-note/issues/02-editing-autosave.md` (primary, its checkboxes are the DoD) + `docs/spec-sticky-note-v1.md` (user stories + amendments).
**Purpose of this file:** input for the review-cleanup pass. Findings are recorded verbatim-enough to act on; the fixer session works from this file.

**Status: open (fresh review, 2026-09-01).** Standards is essentially clean (one mild judgement-call DRY). The Spec axis carries the real work: the ticket's scroll box is a genuine, still-in-scope gap, and the commit-flush regression is racy and under-covers user story 10. The diff's 11 ticks lean mostly on "live-verified" annotations rather than re-demonstration in the diff.

## Standards

Documented standards: `CLAUDE.md` (the load-bearing rule — "All decisions live in `logic/`; the QML only applies results"; the position map "refuses to guess") and `README.md` (few code-style rules). No lint tooling. Note: this codebase is deliberately and heavily commented, so comments are the norm, not a smell.

### logic/BoldLogic.mjs

- **Duplicated Code** (judgement call) — the unwrap slice `source.slice(0,a)+source.slice(a+2,b-2)+source.slice(b)` appears in the new whole-span branch (BoldLogic.mjs:88-92) and again verbatim in `toggleCaret` (BoldLogic.mjs:120). Three lines; extracting an `unwrapSpan(source,a,b)` helper is optional given this file's inline-commented style.
- **Clean:** the whole-span decision lives in the logic module (the core contract — QML untouched). `isBoldSpan` reuses the exported `boldSpans` primitive (markers = single source of truth). The branch is correctly conservative: it unwraps only when the trimmed selection *exactly equals one* span (BoldLogic.mjs:87), else falls through to wrap. Branch order (open+close before `isBoldSpan`) is sound — both paths yield identical results for content-only vs whole-span selections. Matches the "refuses to guess" spirit.

### tests/BoldLogic.test.mjs

**Clean.** All three new tests follow file conventions: they exercise the public `toggleBold` seam (not the private `isBoldSpan`), use `assert.deepEqual` on the full result object, carry a one-line intent comment each, and sit in the "with a selection" section after the existing unwrap tests. Test 3 locks in the conservative fall-through-to-wrap — a good regression. Verified: 31/31 pass.

### tests-harness.qml

**Clean; conventions followed.** The new step mirrors its neighbors exactly: `enqueue({name, run})`, `model.setText/saveNow/dirty`, `sh("cat")+Logic.parseState` + `assertEq`/`assertTruthy` (same shape as the "explicit save" step at :128). The comment's claim "the way the view's commit binding does" is accurate — `NoteWindow.qml:159-162` calls `model.saveNow()` on focus loss. One observation (not a smell): the `setText→saveNow→cat` shape overlaps the "explicit save" and "recover" steps, but each asserts a distinct contract; step-scaffolding repetition is expected.

### .scratch/sticky-note/issues/02-editing-autosave.md

Ticket bookkeeping, not code. Ticks carry "live-verified" / "harness regression" annotations, consistent with CLAUDE.md's "never tick a checkbox you have not verified." Clean.

**Worst Standards issue:** the mild Duplicated-Code unwrap expression (BoldLogic.mjs:88-92 vs :120) — a judgement call, optional extract.

## Spec

### (a) Requirements missing or partial

- **The scroll box is a genuine gap, not a deferral** (ticket:22 — "the note scrolls internally (word-wrapped, no horizontal scrollbar), and the end of the text is reachable"). It is the sole unchecked box. The real-window amendment supersedes only US 3, 4, 13, 14–19, 32, 34; the scroll stories (US 21 "scroll inside itself… no text hidden unreachably," US 23 word-wrap) are *not* superseded, so the requirement is still in scope. `NoteWindow.qml` already has `Flickable` + vertical `ScrollBar` + `wrapMode: Wrap`, so this is a **verification gap** (box unticked = not demonstrated), not a code gap. **The ticket is not done.**
- **Commit-flush (US 10) only partially covered** (US 10: "every character I type saved automatically, so that a crash, power loss, or reboot costs me nothing"). The new harness step tests the `saveNow()` primitive but not (i) the view's commit binding (`NoteWindow.qml:159-162`, focus-loss/Escape→`saveNow`) nor (ii) the teardown flush `Component.onDestruction: saveNow()` (`NoteStateModel.qml:54`) — the actual reboot/logout path. The step's "user story 10" citation is loose: it really proves the ticket's commit-time box (ticket:23 "does not lose the final keystrokes… at commit time"). Its proof is also racy: it `cat`s with **no settle wait** (siblings wait 500ms post-`saveNow`, e.g. tests-harness.qml:129, :193), so it can read pre-flush content — a demonstration, not an airtight proof.
- **The other 9 ticks rest only on "live-verified" annotations** (ticket:19, :20, :21); the diff doesn't re-demonstrate them. That is acceptable under the repo's live-verification convention, but it means the diff alone doesn't close the ticket.

### (b) Behaviour not asked for (scope creep)

- **None substantive.** The `isBoldSpan` unwrap is the bug fix ticket:13 demands ("Ctrl+B again unwraps it (identity round-trip)"); the 3 tests and the harness step map to ticked boxes. Minor: the diff ticks 11 boxes but only 2 (round-trip, final-keystrokes) have supporting code *in this diff*; the rest ride on prior manual verification.

### (c) Looks implemented but wrong

- **Core logic is correct.** All 3 new tests pass and assert the ticket's claims: whole-span unwrap end-to-end, unwrap among other text, and cross-span staying conservative — `isBoldSpan` requires `[a,b)` to *exactly* equal one `boldSpans` span, so `"**a** **b**"` [0,11) matches neither and conservatively wraps to `****a** **b****`, no mangling. Whole-span unwrap restores the inner content as the selection, consistent with the pre-existing inner-unwrap branch. The one real weakness is the racy harness step in (a).

## Summary

Standards — 1 finding (judgement call), worst: the mild Duplicated-Code unwrap expression in `logic/BoldLogic.mjs` (optional `unwrapSpan` extract).
Spec — 3 gaps + 1 minor scope note, worst: the scroll requirement (ticket:22) is a genuine, still-in-scope requirement that is not demonstrated, so the ticket is not actually done; runner-up: the commit-flush regression (tests-harness.qml) is racy (no settle wait) and under-covers US 10 (no binding or teardown-flush coverage).

## Cleanup decisions made by the user (recorded here for the fixer)

1. **unwrapSpan extract — accepted.** Extracted as `unwrapSpan(source, a, b)` in `logic/BoldLogic.mjs`; both call sites use it.
2. **Racy commit-flush step — fixed, with a corrected rationale.** The race is confirmed (verified against quickshell: `FileView.setText` writes asynchronously; `blockWrites` defaults false), but the reviewer's "match the siblings" remedy only works because `saveNow()` stops the debounce unconditionally first — the flush is the only possible writer, so waiting cannot mask a broken flush. The step now waits and its comment says this.
3. **US 10 under-coverage (teardown flush) — closed with a new harness step**: destroying a model holding a pending tail flushes it. Passing also demonstrates the async write survives `destroy()`.
4. **Scroll (ticket:22) — verified live** by Jon on the standalone dev run (30 seeded paragraphs, distinctive final line): wheel scroll, word-wrap with no horizontal scrollbar, end reachable. Box ticked; ticket status → done (4ef8279).
5. **9 ticks resting on live-verified annotations — no action.** The annotations are the demonstration record; CLAUDE.md asks for demonstration, not re-demonstration in the diff.

**Remediated in** 1028370 (review fixes) and 4ef8279 (scroll tick + ticket closure). Full suite green after both: 38 node tests + harness ALL PASS.