# Code review findings — omarchy-plugin-marketplace submission #4250

**Review source:** collaborator review on the marketplace issue (HANCORE-linux, 2026-09-01), after the automated validation + security baseline passed at `9d2e22c`.
**Spec source:** `docs/spec-sticky-note-v1.md` + the amendment at its bottom (stored text is the single source of truth; bold-only formatting promise; real-window amendment).
**Purpose of this file:** input for the remediation pass. Findings are recorded verbatim-enough to act on, each with a decision.

**Status: addressed in the marketplace-remediation commits, 2026-09-01.** Four items fixed and live-verified; one declined with reasoning (documented limitation). Full suite green after remediation: 45 node tests + all quickshell harness steps (`./tests/run.sh`).

## The findings, verbatim-enough, with decisions

1. **"Declare the existing MIT license in the manifest."** — **Accepted.** `"license": "MIT"` added to `manifest.json`; `omarchy plugin validate` still passes (schema accepts the field).

2. **"Private note state is created and consumed through pathname-based mkdir/FileView operations without a verified 0700 owner-only directory … or a guaranteed 0600 atomic write."** — **Accepted (the permission halves), already-satisfied (the atomic half).**
   - The live directory was `755` and the file `644` — the reviewer was right, the note's contents were world-readable. Fixed: `Service.qml`'s startup Process now runs `mkdir -p -m 700` + `chmod 700` + `chmod 600` on an existing file, every session. Live-verified after `omarchy restart shell`: dir `700`, file `600`, text intact.
   - "Guaranteed atomic write": already satisfied — both `FileView`s in `NoteStateModel.qml` set `atomicWrites: true` (write-to-temp + replace), predating the review; now documented here.
   - Per-write mode enforcement is FileView-owned and not configurable from QML; the startup chmod brings every file the note itself created up to 0600. Residual: a file created between sessions by an external writer keeps that writer's mode until the next startup chmod. Accepted residual.

3. **"Idle display interprets restored note content as full Markdown rather than a constrained plain/bold-only format."** — **Accepted; the best finding.** `NoteWindow.qml` bound the idle face to `TextEdit.MarkdownText`, and QML markdown renders images and links — a pasted `![](https://…)` would have fired a network request when the note idled, beyond anything the spec promised (bold only, spec user story + bold amendment). Fixed: new `boldOnlyHtml(source)` in `logic/BoldLogic.mjs` (the logic seam, per the repo contract) — HTML-special characters escaped first, then paired `**`→`<b>`, then `\n`→`<br>`; the output can only ever contain `<b>`, `<br>`, and inert text. The idle face binds to it with `TextEdit.RichText`. Six node tests cover the renderer (tags escaped, entities escaped, unpaired markers literal, docToSource round-trip preserved). Live-verified: the installed note renders `**Todo**` bold and a pasted `[` literal, no markers leaking.

4. **"No read-size cap."** — **Accepted.** `MAX_STATE_BYTES` (4 MiB) in `logic/NoteStateLogic.mjs`; `Service.qml`'s startup gate refuses to hand over the path for a document over the cap (exit 42, loud warning), so the note runs on defaults rather than reading the file into memory whole. Live-verified with a seeded 5 MiB throwaway state file: the warning fired and the note came up on defaults. Document values remain uncapped — see 5.

5. **"Text, parsed state, corrupt backups, and restored geometry are also unbounded."** — **Declined for document values.** This was a deliberate, recorded decision (ticket 05, tested in `tests/NoteStateLogic.test.mjs` "an absurd-but-well-typed size is accepted"): the document is a *record*, not a driver — placement is compositor-owned, sizes are never applied to the window, so an absurd recorded size consumes only the bytes it occupies. The only unbounded *resource* on the load path was the file read itself, which finding 4's cap closes. Corrupt backups are bounded by the same cap at startup. A future cap on document values would mean rejecting (and preserving-as-invalid) well-typed documents — a data-loss path for zero resource gain once the read is capped.

6. **"Move state I/O behind descriptor-relative bounded helpers with explicit modes, no-follow/nonblocking regular-file checks."** — **Declined as an architecture change.** quickshell's `FileView` owns the actual `open()`; flags like `O_NOFOLLOW` are not expressible from QML, so this ask means replacing the storage layer with custom POSIX plumbing (Process-driven or native), discarding the model's watcher, atomic-write, and startup-race guarantees for a single-user desktop note. The realistic threat model (another local user) is addressed by the 0700/0600 modes in finding 2; a same-UID attacker can do anything anyway. Recorded as a documented limitation rather than silently dropped — revisit if the plugin ever manages multi-user or untrusted-input state.

## Verification

- 45/45 node tests (6 new for `boldOnlyHtml`), full `./tests/run.sh` harness ALL PASS.
- Live: `omarchy restart shell` → dir `700` / file `600`, note text intact, idle face renders bold-only correctly.
- Live: seeded 5 MiB state file → refusal warning, note on defaults, real note untouched.