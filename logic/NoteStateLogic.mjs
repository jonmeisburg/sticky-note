// Seam 1 — the note's state document, as pure logic.
//
// The state model (load / save / watch-reload) lives in NoteStateModel.qml;
// every decision it makes is delegated to this module so it can be tested
// without a display. The on-disk contract is one human-readable JSON file:
//
//   { "text": "...", "x": 16, "y": 16, "width": 300, "height": 300 }
//
// Tunable feel constants live here, all in one place (spec: the threshold
// and size floor must be adjustable without hunting through the code).

export const DEFAULT_X = 16
export const DEFAULT_Y = 16
export const DEFAULT_WIDTH = 300
export const DEFAULT_HEIGHT = 300

// Below this the note is an unreadable sliver (spec user story 19). The
// window enforces it as a native minimumSize; load-time clamping uses it
// too, so a hand-edited document can't restore a sliver.
export const MIN_WIDTH = 140
export const MIN_HEIGHT = 140

export function defaults() {
  return {
    text: "",
    x: DEFAULT_X,
    y: DEFAULT_Y,
    width: DEFAULT_WIDTH,
    height: DEFAULT_HEIGHT,
  }
}

function isFiniteNumber(value) {
  return typeof value === "number" && isFinite(value)
}

// Parse raw file contents. Anything that is not a well-formed state
// document is rejected ({ ok: false }) so the caller can fall back to
// defaults without crashing (spec user story 30). Absurd-but-well-typed
// values are NOT rejected here — clamping at load is their recovery path
// (spec user story 34, ticket 05).
export function parseState(raw) {
  if (typeof raw !== "string") return { ok: false }
  var doc
  try {
    doc = JSON.parse(raw)
  } catch (e) {
    return { ok: false }
  }
  if (typeof doc !== "object" || doc === null || Array.isArray(doc)) return { ok: false }
  if (typeof doc.text !== "string") return { ok: false }
  if (!isFiniteNumber(doc.x) || !isFiniteNumber(doc.y)) return { ok: false }
  if (!isFiniteNumber(doc.width) || !isFiniteNumber(doc.height)) return { ok: false }
  return {
    ok: true,
    state: {
      text: doc.text,
      x: Math.round(doc.x),
      y: Math.round(doc.y),
      width: Math.round(doc.width),
      height: Math.round(doc.height),
    },
  }
}

function knownScreen(screenW, screenH) {
  return isFiniteNumber(screenW) && isFiniteNumber(screenH) && screenW > 0 && screenH > 0
}

// Load-time recovery (spec user story 34): whatever was saved, the restored
// size must be sane on this screen. Placement itself is compositor-owned
// (the note is a real window), so this protects only what the document
// feeds back at spawn — the window's size.
export function clampToScreen(state, screenW, screenH) {
  if (!knownScreen(screenW, screenH)) return state
  var width = Math.min(Math.max(Math.round(state.width), MIN_WIDTH), Math.round(screenW))
  var height = Math.min(Math.max(Math.round(state.height), MIN_HEIGHT), Math.round(screenH))
  var x = Math.min(Math.max(Math.round(state.x), 0), Math.round(screenW) - width)
  var y = Math.min(Math.max(Math.round(state.y), 0), Math.round(screenH) - height)
  return { text: state.text, x: x, y: y, width: width, height: height }
}

export function serializeState(state) {
  return JSON.stringify(
    {
      text: state.text,
      x: Math.round(state.x),
      y: Math.round(state.y),
      width: Math.round(state.width),
      height: Math.round(state.height),
    },
    null,
    2
  ) + "\n"
}