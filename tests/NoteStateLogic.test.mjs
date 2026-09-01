import test from "node:test"
import assert from "node:assert/strict"
import * as State from "../logic/NoteStateLogic.mjs"

// The state document is the product's public on-disk contract (spec v1):
// one human-readable JSON file holding the note's text and geometry.

test("defaults: fresh note is 300x300 near the top-left, empty text", () => {
  const d = State.defaults()
  assert.equal(d.text, "")
  assert.equal(d.width, 300)
  assert.equal(d.height, 300)
  assert.ok(d.x >= 0 && d.x < 100, "default x is top-left-ish")
  assert.ok(d.y >= 0 && d.y < 100, "default y is top-left-ish")
})

test("parse: reads a hand-written human state document", () => {
  // Independent source of truth: exactly what a user would hand-edit
  // in a terminal (spec user story 29/30).
  const raw = `{
  "text": "buy oat milk",
  "x": 420,
  "y": 88,
  "width": 500,
  "height": 700
}
`
  const result = State.parseState(raw)
  assert.ok(result.ok)
  assert.deepEqual(result.state, {
    text: "buy oat milk",
    x: 420,
    y: 88,
    width: 500,
    height: 700,
  })
})

test("parse: malformed and truncated files are rejected, not crashed on", () => {
  for (const bad of ["", "{", "not json at all", "[]", '{"text": "hi"}', null, undefined]) {
    const result = State.parseState(bad)
    assert.equal(result.ok, false, `expected rejection for ${JSON.stringify(bad)}`)
    assert.equal(result.state, undefined)
  }
})

test("parse: structurally valid JSON with wrong-typed fields is rejected", () => {
  for (const bad of [
    '{"text": 5, "x": 1, "y": 1, "width": 10, "height": 10}',
    '{"text": "a", "x": "1", "y": 1, "width": 10, "height": 10}',
    '{"text": "a", "x": 1, "y": 1, "width": NaN, "height": 10}',
  ]) {
    const result = State.parseState(bad)
    assert.equal(result.ok, false, `expected rejection for ${bad}`)
  }
})

test("parse: an absurd-but-well-typed size is accepted — the document is a record, not a driver", () => {
  // A note sized huge on a big monitor (3800x2400) must still load on any
  // machine after a monitor/resolution change: the load path never rejects
  // or clamps the recorded size, because it never applies it to the
  // window either — the compositor owns placement and the window's
  // native minimumSize is the only size limit (ticket 05: the note can
  // never strand itself off-screen).
  const result = State.parseState('{"text": "big", "x": 10, "y": 10, "width": 3800, "height": 2400}')
  assert.ok(result.ok)
  assert.deepEqual(result.state, { text: "big", x: 10, y: 10, width: 3800, height: 2400 })
})

test("serialize: round-trips through parse and is stable, pretty JSON", () => {
  const original = { text: "line one\nline two", x: 100, y: 200, width: 340, height: 500 }
  const raw = State.serializeState(original)
  assert.equal(raw, JSON.stringify(original, null, 2) + "\n")
  const result = State.parseState(raw)
  assert.ok(result.ok)
  assert.deepEqual(result.state, original)
})

test("paperToWindowSize / windowToPaperSize: the shadow margin offsets the two faces", () => {
  const margin = 12
  assert.equal(State.paperToWindowSize(300, margin), 324)
  assert.equal(State.windowToPaperSize(324, margin), 300)
  // the round trip is exact, at the floor and off it
  assert.equal(State.windowToPaperSize(State.paperToWindowSize(State.MIN_WIDTH, margin), margin), State.MIN_WIDTH)
  assert.equal(State.windowToPaperSize(State.paperToWindowSize(512, margin), margin), 512)
})

test("sameState: deep, key-order-independent document comparison", () => {
  const a = { text: "buy milk", x: 10, y: 20, width: 300, height: 400 }
  const reordered = { height: 400, width: 300, text: "buy milk", x: 10, y: 20 }
  assert.ok(State.sameState(a, reordered), "key order does not matter")
  assert.ok(State.sameState(a, a), "identical objects compare equal")
  assert.ok(!State.sameState(a, { ...a, text: "buy oats" }), "a different text does not")
  assert.ok(!State.sameState(a, { ...a, width: 400 }), "a different size does not")
  assert.ok(!State.sameState(a, { ...a, extra: 0 }), "extra fields do not")
  assert.ok(!State.sameState(a, { text: "buy milk", x: 10, y: 20, width: 300 }), "missing fields do not")
  assert.ok(!State.sameState(a, null))
  assert.ok(!State.sameState(null, a))
})
