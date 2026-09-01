# sticky-note

A single persistent sticky note as a real Hyprland-managed window: it
tiles alongside your windows (never buried behind them), floats and
resizes with your native binds, and only takes keystrokes when focused
like any other window. Click to type; click away or Escape to commit.
Text and size survive reboots. Shipped as an [Omarchy](https://omarchy.org)
quickshell plugin.

**Bold:** Ctrl+B toggles bold over the selection, or the word the caret
touches. Bold is stored as markdown `**` markers in the text itself, so
while editing you see the raw source (`**word**`); once the note is idle,
the markdown renders and bold words appear bold.

State lives in `~/.config/sticky-note/note.json` — one human-readable JSON
document holding the note's text plus its recorded size. Placement is the
compositor's business: the document's x/y are recorded for reference but
never applied, and when the note tiles the compositor may reshape it — the
settled size is what gets recorded back. Text is restored exactly. A corrupt
file falls back to safe defaults and is preserved as `note.json.invalid-*`
rather than overwritten.

## Install

On Omarchy, install straight from this repo:

```bash
omarchy plugin add https://github.com/jonmeisburg/sticky-note --enable
```

There is nothing to launch after that — the note is a *service*, not an app:
omarchy-shell mounts it at login and the window is simply there, tiled
alongside your windows. Click it to type; click away or press Escape to
commit. Float it with your usual float bind to drag it anywhere.

Disable or remove it with `omarchy plugin disable sticky-note` /
`omarchy plugin remove sticky-note`.

## Development

To hack on it from a working copy, symlink your checkout into the shell's
plugin directory and enable it:

```bash
ln -s ~/Projects/sticky-note ~/.config/omarchy/plugins/sticky-note
omarchy plugin enable sticky-note
```

(`omarchy plugin enable` adds the plugin to `plugins[]` in
`~/.config/omarchy/shell.json`; the shell loads enabled services at every
startup, which is the login autostart path.)

Two iteration loops, by how live you need the result:

**Standalone (fully hot-reloading).** Run the note outside the shell against
a throwaway state file:

```bash
STICKY_NOTE_STATE=/tmp/note.json quickshell -p .
```

Quickshell watches the config root — this repo — so every save reloads
instantly (verified: the note surface is recreated on save). Use this for
visual iteration.

**Inside the shell (manual refresh).** The symlinked install does not
auto-reload: the shell's plugin watcher is `inotifywait -r` over
`~/.config/omarchy/plugins/`, which does not traverse symlinked
directories, so repo saves never reach it. Refresh the installed instance
with the sanctioned mechanism:

```bash
omarchy restart shell
```

(`omarchy-shell shell rescanPlugins` exists but proved unreliable for
applying code changes — a restart always does.)

## Tests

```bash
./tests/run.sh
```

1. `node --test` over the pure logic seams — the state-document logic and
   the bold toggle/position map — no display needed.
2. A live quickshell instance drives `NoteStateModel.qml` against a real
   temp file: save/load round-trips, debounced autosave, external-edit
   following, corrupt-file fallback, and the startup-race regression
   (a save before the first read can never clobber the file). Requires a
   running Wayland session.