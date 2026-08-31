# sticky-note

A single persistent sticky note as a real Hyprland-managed window: it
tiles alongside your windows (never buried behind them), floats and
resizes with your native binds, and only takes keystrokes when focused
like any other window. Click to type; click away or Escape to commit.
Text and size survive reboots. Shipped as an [Omarchy](https://omarchy.org)
quickshell plugin.

State lives in `~/.config/sticky-note/note.json` — one human-readable JSON
document (`text`, `x`, `y`, `width`, `height`). Text is restored exactly;
size is restored at spawn and then follows the compositor. A corrupt file
falls back to safe defaults and is preserved as `note.json.invalid-*`
rather than overwritten.

## Install

The plugin runs inside the Omarchy shell and launches at login once enabled:

```bash
ln -s ~/Projects/sticky-note ~/.config/omarchy/plugins/sticky-note
omarchy plugin enable sticky-note
```

`omarchy plugin enable` adds the plugin to `plugins[]` in
`~/.config/omarchy/shell.json`; the shell loads enabled services at every
startup, which is the login autostart path. Disable with
`omarchy plugin disable sticky-note`.

## Development

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

1. `node --test` over the state-document logic (the project's one pure
   seam) — no display needed.
2. A live quickshell instance drives `NoteStateModel.qml` against a real
   temp file: save/load round-trips, debounced autosave, external-edit
   following, and corrupt-file fallback. Requires a running Wayland session.