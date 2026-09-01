# Code review findings — ticket 01 implementation

**Review:** two-axis (Standards + Spec), fresh session, against commits `66591b8..192fb8c` and the amended spec.
**Purpose of this file:** input for the review-cleanup pass. Findings are recorded verbatim-enough to act on; the fixer session works from this file.

**Status: addressed in `d0b83b9` (review-cleanup pass, 2026-09-01).** All seven Standards findings and the Spec findings are resolved per the cleanup decisions below: the caret fallback moved to `Bold.tapCaret` (node-tested), the adopt-before-`loaded`-flip ordering fixed in `NoteStateModel.qml`, story-34 x/y clamping deleted, shadow-margin math and `sameState` extracted into `NoteStateLogic`, stale comments fixed, and CLAUDE.md updated. The strengthened startup-race regression was verified to fail when either the write guard or the ordering is reverted. **Still open (deliberately, per the recorded decisions):** ticket 05's clamping checkbox is in tension with the amendment and will be amended by the user separately; ticket 02's status/checkboxes lag the code.

## Standards

No documented repo standards exist (no CODING_STANDARDS/CONTRIBUTING/AGENTS.md, no lint tooling), so all findings are judgement calls; no hard violations.

### NoteWindow.qml

- **LEAKED DECISION** — `textEdit.cursorPosition = src === null ? textEdit.length : src` (NoteWindow.qml:230). The bold amendment says "All position decisions live in the logic module… the view only applies results," but the null→end-of-text fallback is a position decision made in the view, covered by no node test.
- **LEAKED DECISION (residue)** — `property bool editing: false` (NoteWindow.qml:87). A hand-rolled idle/editing flag from the dissolved machine; it's invariant with `textEdit.activeFocus`, so the four `root.editing` bindings (:137, :144, :202, :222) could bind `activeFocus` directly. Judgement call — it's documented and behaves correctly.
- **Duplicated Code** — the ±shadowMargin*2 window↔paper geometry math recurs three times: minimumSize (:42), spawn sizing (:51–54), syncGeometry (:74–79). Gather into one helper.
- Clean: no gesture thresholds, click-vs-drag logic, or region classification; the focus bindings (:157–160, :164) are the "one binding each" the spec explicitly sanctioned.

### NoteStateModel.qml

- **Duplicated Code** — `JSON.stringify(next) !== JSON.stringify(state)` state comparison at :67, :100, :138; extract a `Logic.sameState()` (deep, key-order-independent) into the logic module.

### NoteStateLogic.mjs

- **Mysterious Name / dissolved-machine residue** — header :9–10: "the threshold and size floor must be adjustable" — the threshold (`CLICK_THRESHOLD_PX`) lived in the deleted Interaction.mjs; no threshold exists in the codebase.
- **Speculative Generality** — x/y are validated (:52), clamped (:78–79), and persisted but never applied (placement is compositor-owned; the window only consumes width/height). Dead machinery around a record-only field.

### tests/run.sh

- **Dissolved-machine residue** — :4–5: "node --test over the pure logic seams (state document + interaction state machine)" — that machine was deleted in 35a7b2e; the second node seam is now the bold seam.

### Clean (one line each)

Service.qml; shell.qml; logic/BoldLogic.mjs (dense but fully node-tested; a0/b0 at :57 a nit); tests-harness.qml; tests/NoteStateLogic.test.mjs; tests/BoldLogic.test.mjs; Commons/*; manifest.json; README.md; docs/spec amendments (kept deliberately as record).

**Worst Standards issue:** the untested null→end-of-text caret fallback at NoteWindow.qml:230 breaks the spec's own "view only applies results" seam contract.

## Spec

### (a) Requirements missing or partial

- **"re-syncs once after, so observed size is still recorded" (spec:202-203).** The re-sync exists (NoteWindow.qml:69-72) but is defeated by ordering: `onLoaded` sets `_loaded=true` (NoteStateModel.qml:173), which synchronously fires the view's `onLoadedChanged`→`syncGeometry()` **before** `adopt()` (line 176). `adopt` then overwrites state with the disk doc, discarding the observed size. Net recorded size is the disk (floored) value, not the observed spawn size. Inert while auto-tiled (ticket 05:9 known gap).
- **Ticket 02 is ready-for-agent, yet its bold + autosave contract is fully implemented in the diff** (BoldLogic.mjs; NoteWindow.qml:169-178, 194-235). Ticket status lags the code. → *Process note: verify the behaviors and tick ticket 02's checkboxes, or record in the ticket what's already built.*
- **Ticket 05 hardening items remain unchecked:** off-screen clamp at load, monitor-change, extended-use stability, full DoD. Only the startup race is done.

### (b) Behaviour not asked for (scope creep)

- **x/y on-screen clamping** in `clampToScreen` (NoteStateLogic.mjs:78-79) and the screen-change `reclamp()` (NoteStateModel.qml:54-55). The amendment deleted story 34 — "the compositor owns placement, so on-screen stranding is no longer our failure mode" (spec:127); only the size floor survives (spec:124). x/y clamping is a leftover of the deleted semantics. (Note: ticket 05:12 still lists clamping — in tension with the amendment; **decision: amendment wins, ticket 05 to be amended separately by the user.**)

### (c) Looks implemented but wrong

- The startup-race re-sync (NoteWindow.qml:69-72) reads as "observed size recorded," but the adopt-before-re-sync ordering makes it ineffective for the observed size. Same root cause as (a) item 1.

## Focus areas

1. **Amendment-vs-code agreement** — the window is a real client: FloatingWindow (NoteWindow.qml:24), title "Sticky Note" (:29), kinds ["service"] (manifest.json). No layer-shell/Panel/behindWindows anywhere — background-layer surface fully gone. Floor survives as native `minimumSize` (:42-43). Geometry observed, never driven: spawn-sized once via implicitWidth/Height (:51-54), FloatingWindow exposes no x/y (:48-50), onWidthChanged/onHeightChanged record back (:63-64). Leftover: x/y clamping (deleted story-34 semantic).
2. **Dissolved-machine leak** — machine gone; logic/ holds only NoteStateLogic + BoldLogic; commit is one binding each as amended. Only unreviewed decision: the `editing` bool (NoteWindow.qml:87), hand-synced with activeFocus. The idle tap-catcher MouseArea (:221-235) is a new entry point from the bold amendment, not the old classifier.
3. **BoldLogic test bar** — style matches seam-1 (pure node, external behavior). All six amended-contract behaviors covered. Gaps: (i) docToSource only tests a single mid-doc span — no multi-span, none at doc start/end; (ii) refuse case covers only italics+heading, no list; (iii) round-trip only for the selection path, not word-at-caret/empty-marker; (iv) the "caret falls to end" fallback is view logic (:230) — only the null return is asserted.
4. **Startup race (ticket 05)** — model implements the contract (`saveNow` guard, `adopt` unconditional + clears `_dirty`). Regression test would fail if "first read adopts unconditionally" were reverted, but does not reliably exercise the "debounce fires before read" window: the fast local read lands before the 500ms debounce and adopt has already cleared `_dirty`, so removing just the `!_loaded` guard would still pass. **Verdict: genuine regression for the adopt half, happy-path for the write-guard half.**

## Summary

Standards — 7 findings, worst: untested null→end caret fallback (NoteWindow.qml:230) breaking the "view only applies results" seam contract.
Spec — 3 findings, worst: the x/y clamping leftover (deleted story 34) plus the adopt-before-re-sync ordering that silently defeats the "observed size still recorded" claim.

## Cleanup decisions made by the user (recorded here for the fixer)

1. Move the null→end caret fallback into BoldLogic; node-test it.
2. Fix adopt-before-re-sync ordering; strengthen the harness regression for the debounce-before-read window.
3. Delete x/y clamping (`clampToScreen`, `reclamp`) — spec amendment removed story 34. Ticket 05's clamping checkbox will be amended by the user separately.
4. Extract duplicated shadow-margin math and same-state comparison into logic helpers.
5. Fix stale comments (NoteStateLogic.mjs:9-10, tests/run.sh:4-5).
6. Do NOT start ticket 02; do NOT amend ticket 05's checkbox (user does that).