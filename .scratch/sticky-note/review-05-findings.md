# Code review findings — ticket 05 (hardening + done)

**Review:** two-axis (Standards + Spec), fresh sessions, against the uncommitted ticket-05 diff (tests/NoteStateLogic.test.mjs, tests-harness.qml, .scratch/sticky-note/issues/05-hardening-done.md) and the amended spec.
**Spec source:** `.scratch/sticky-note/issues/05-hardening-done.md` (primary, its checkboxes are the DoD) + `docs/spec-sticky-note-v1.md` (user stories + both 2026-08-31 amendments).
**Purpose of this file:** input for the review-cleanup pass. Findings are recorded verbatim-enough to act on; the fixer session works from this file.

**Status: addressed in the ticket-05 closure commits, 2026-09-01.** Standards: clean (no findings; two dismissed judgement calls below). Spec: one real gap + two nits — the spec DoD's "week of real use" clause was missing from box-5's walk; remediated by adding the clause to the walk as an explicitly-standing item (closed by the user's real use over time, not demonstrated same-day). Both backing tests re-run green: node suite 39/39 + full `./tests/run.sh` (churn step included).

## Standards

Documented standards: `CLAUDE.md` (the load-bearing rule — "All decisions live in `logic/`; the QML only applies results"; process artifacts are load-bearing; verify-only tickets ticked only after live demonstration, recorded as `*(live-verified: …)*` annotations) and `README.md` (few code-style rules). No lint tooling. No hard violations.

### tests/NoteStateLogic.test.mjs

Clean. The new test ("parse: an absurd-but-well-typed size is accepted") follows the file's conventions: `parse:`-prefixed name beside its neighbors, `assert.ok(result.ok)` + `assert.deepEqual(result.state, …)` matching the parse siblings, a multi-line intent comment (this file is deliberately heavily commented), and it asserts only the public `State.parseState` seam — no internal-variable inspection. Passes (8/8). Dismissed judgement call: the comment's "(ticket 05: the note can never strand itself off-screen)" loosely couples *size* to *stranding* (a placement property); the substantive claim — load never rejects/clamps a well-typed size, the native `minimumSize` is the only limit — is accurate.

### tests-harness.qml

Clean. The new "churn" step mirrors its neighbors' shape: `enqueue({name, run})` with a multi-line intent comment; `model.setText/saveNow/dirty` + `sh("cat")+Logic.parseState` + `assertEq/assertTruthy`, same as "explicit save" and "commit flush". No race: it applies the settle-wait discipline review-02 codified (wait(500) before the `cat` after `saveNow()` — the flush is the only writer, so the wait cannot mask a broken write; wait(1000) after the external `printf`, mirroring "external edits"). No leaked decision: the step only drives the model API and asserts external behavior; the 50/8/400ms figures are test pacing, not product decisions. Dismissed: the recursive `churn` helper and the repeated setText+saveNow+wait pattern read as step-scaffolding repetition, which review-02 already ruled expected.

### .scratch/sticky-note/issues/05-hardening-done.md

Clean. Status → `done (all boxes verified live 2026-09-01; recipe in verify-live.md)`, matching the ticket-03/04 convention; the three new ticks carry `*(live-verified: …)*` annotations in the documented verify-only form, each citing its oracles (hyprctl / state file / RSS) and cross-referencing the new node test and harness step as seam-backing — exactly CLAUDE.md's "tick only what you demonstrated". Dismissed judgement calls: (a) "all boxes verified live" is slightly loose — the "sits behind windows" sub-item and the "Superseded…" box are closed as *superseded*, not live-verified; the annotation records the superseded item explicitly ("closed, not silently dropped"), and closing superseded boxes is the ticket's established convention. (b) The DoD box's annotation extends the single-line `*(live-verified: …)*` to a multi-line bulleted form — still inside the `*(…)*` parenthetical, a reasonable adaptation for a 6-item checklist.

**Worst Standards issue:** none — all three files clean.

## Spec

### (a) Requirements missing or partial

- **The spec's DoD stability clause is not walked** (spec:103 — "never crashes or loses data over *a week of real use*"). Box-5's item-by-item list omits that clause; it is handled only by box-2 as a same-day "long session" (8 churn cycles + 5 restarts), a shorter stand-in. Box-5's claim that "the full definition-of-done checklist from the spec passes" therefore overstated the record. **Remediated:** the clause was added to box-5's walk as an explicitly-standing item — same-day stand-in (box-2's pass), closed by the user's real use over time, recorded as standing, not demonstrated.
- **Mirror image of the same mismatch:** box-5's "never steals focus unprompted" is not a DoD-paragraph clause — it comes from the Testing-Decisions checklist (spec:86). So the walked checklist ≠ the spec's DoD checklist (one clause dropped, one added). Harmless: the walk now covers the spec's clauses plus the extra; the dropped clause is the standing one above.

### (b) Behaviour not asked for (scope creep)

- **None.** Both new tests are cited by the box annotations (ticket boxes 1–2) and back exactly the ticket's seams ("no data loss" / "watcher survives"; "a recorded size is never rejected or clamped at load"). The diff touches only the three expected files.

### (c) Looks implemented but wrong

- **Superseded items handled correctly.** "sits behind windows" is explicitly closed as superseded US 3 (ticket ↔ spec:120-121), not silently dropped. The focus annotation is consistent with the amendment's US-4 semantics ("a real window is focused, alt-tabbed, and tiled like any other"): verified no spawn-time focus request (NoteWindow.qml's `Component.onCompleted` sets only implicit sizes; the sole `forceActiveFocus` sites are the click path and the Escape commit; `Service.qml` has none), and the post-restart re-map focus is explicitly framed as the amendment's trade, not a self-request.
- **Box 1 and box 2 match their oracles.** Monitor-shrink → re-tile → restart → byte-identical text + edit + autosave matches `verify-live.md`'s oracles (compositor truth + state file); the churn step matches its annotation (50-burst settles to its last edit; 8 self-writes then an external edit is adopted) and was re-run green.
- **Nits (no action):** "no resource growth" (box-2's ticket text) rests on a bounded RSS series 701.4→702.6 MB — the annotation's "bounded … (no growth trend)" wording is the honest reading, and the box text is the ticket's own. "91-line" scroll document is accurate (90 numbered lines + 1 END marker line = 91 lines; the reviewer's off-by-one read of `SN5-END-90` as line 91 is a misread).

## Summary

Standards — 0 findings (all three files clean; two dismissed judgement calls).
Spec — 1 real gap (the "week of real use" clause, now remediated in the ticket as a standing item) + 2 nits (dismissed). Full suite green after remediation: 39 node tests + harness ALL PASS.