// Seam 1 — the note's state document, as pure logic.
//
// The state model (load / save / watch-reload) lives in NoteStateModel.qml;
// every decision it makes is delegated to this module so it can be tested
// without a display. The on-disk contract is one human-readable JSON file:
//
//   { "text": "...", "x": 16, "y": 16, "width": 300, "height": 300 }
//
// Tunable constants live here, all in one place (spec: the size floor
// must be adjustable without hunting through the code).

export const DEFAULT_X = 16
export const DEFAULT_Y = 16
export const DEFAULT_WIDTH = 300
export const DEFAULT_HEIGHT = 300

// Below this the note is an unreadable sliver (spec user story 19). The
// window enforces it as a native minimumSize, so a hand-edited document
// can't restore a sliver either.
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
// values are NOT rejected here: the document is a record, not a driver —
// placement is compositor-owned, and the only size limit left is the
// window's native minimumSize.
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

// The window carries a drop shadow that spills outside the paper, so a
// window size and its paper (state-document) size are offset by 2*margin.
// The state document holds paper sizes; the window's are derived from them.
export function paperToWindowSize(paperSize, margin) {
  return paperSize + margin * 2
}

export function windowToPaperSize(windowSize, margin) {
  return windowSize - margin * 2
}

// Two state documents carry the same record when they hold the same
// fields with the same values, in any key order — deep, and not subject
// to JSON.stringify's dependence on key order.
export function sameState(a, b) {
  if (a === b) return true
  if (typeof a !== "object" || a === null || typeof b !== "object" || b === null) return false
  var keys = Object.keys(a)
  if (keys.length !== Object.keys(b).length) return false
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    if (!Object.prototype.hasOwnProperty.call(b, key)) return false
    if (JSON.stringify(a[key]) !== JSON.stringify(b[key])) return false
  }
  return true
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