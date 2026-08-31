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

test("serialize: round-trips through parse and is stable, pretty JSON", () => {
  const original = { text: "line one\nline two", x: 100, y: 200, width: 340, height: 500 }
  const raw = State.serializeState(original)
  assert.equal(raw, JSON.stringify(original, null, 2) + "\n")
  const result = State.parseState(raw)
  assert.ok(result.ok)
  assert.deepEqual(result.state, original)
})

test("clampToScreen: a saved position that falls off-screen comes back on-screen", () => {
  // Monitor change: saved for a 2560px screen, now on 1920x1080.
  const clamped = State.clampToScreen(
    { text: "keep me", x: 2500, y: -400, width: 300, height: 300 },
    1920, 1080
  )
  assert.equal(clamped.text, "keep me")
  assert.ok(clamped.x >= 0 && clamped.x + clamped.width <= 1920, `x=${clamped.x}`)
  assert.ok(clamped.y >= 0 && clamped.y + clamped.height <= 1080, `y=${clamped.y}`)
  assert.ok(clamped.x <= 1920 - clamped.width)
})

test("clampToScreen: absurd sizes are floored at the minimum and capped at the screen", () => {
  const clamped = State.clampToScreen({ text: "", x: 10, y: 10, width: 5, height: 100000 }, 1920, 1080)
  assert.equal(clamped.width, State.MIN_WIDTH)
  assert.equal(clamped.height, 1080)
})

test("clampToScreen: unknown screen dimensions leave the state untouched", () => {
  const state = { text: "", x: -50, y: 9999, width: 300, height: 300 }
  assert.deepEqual(State.clampToScreen(state, 0, 0), state)
  assert.deepEqual(State.clampToScreen(state, null, null), state)
})
