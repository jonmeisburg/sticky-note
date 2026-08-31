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

// Below this the note is an unreadable sliver (spec user story 19).
export const MIN_WIDTH = 140
export const MIN_HEIGHT = 140

// A drag must never strand the note: at least this much of it stays
// reachable on each axis (spec user story 34).
export const MIN_VISIBLE_PX = 60

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

// Load-time recovery (spec user story 34, ticket 05): whatever was saved,
// the note must land fully on-screen and at least as large as the size
// floor. A monitor change or hand-edited absurd value can never strand it.
export function clampToScreen(state, screenW, screenH) {
  if (!knownScreen(screenW, screenH)) return state
  var width = Math.min(Math.max(Math.round(state.width), MIN_WIDTH), Math.round(screenW))
  var height = Math.min(Math.max(Math.round(state.height), MIN_HEIGHT), Math.round(screenH))
  var x = Math.min(Math.max(Math.round(state.x), 0), Math.round(screenW) - width)
  var y = Math.min(Math.max(Math.round(state.y), 0), Math.round(screenH) - height)
  return { text: state.text, x: x, y: y, width: width, height: height }
}

// While dragging, the note may hang off any edge, but MIN_VISIBLE_PX of it
// must stay reachable so the user can always grab it again.
export function clampDragPosition(x, y, w, h, screenW, screenH) {
  if (!knownScreen(screenW, screenH)) return { x: Math.round(x), y: Math.round(y) }
  var minX = -(w - MIN_VISIBLE_PX)
  var maxX = screenW - MIN_VISIBLE_PX
  var minY = -(h - MIN_VISIBLE_PX)
  var maxY = screenH - MIN_VISIBLE_PX
  return {
    x: Math.round(Math.min(Math.max(x, minX), maxX)),
    y: Math.round(Math.min(Math.max(y, minY), maxY)),
  }
}

// Corner-drag resize: floor at the readable minimum, cap at the screen.
export function clampResize(width, height, screenW, screenH) {
  var w = Math.max(Math.round(width), MIN_WIDTH)
  var h = Math.max(Math.round(height), MIN_HEIGHT)
  if (knownScreen(screenW, screenH)) {
    w = Math.min(w, Math.round(screenW))
    h = Math.min(h, Math.round(screenH))
  }
  return { width: w, height: h }
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