import test from "node:test"
import assert from "node:assert/strict"
import { InteractionMachine, CLICK_THRESHOLD_PX } from "../logic/Interaction.mjs"

// Seam 2 — the interaction state machine, as pure logic.
// It consumes synthetic pointer events and emits actions; it knows nothing
// about rendering, focus, or files (spec: Implementation Decisions).

function newMachine() {
  return new InteractionMachine()
}

test("the click threshold is a single tunable constant", () => {
  assert.equal(typeof CLICK_THRESHOLD_PX, "number")
  assert.ok(CLICK_THRESHOLD_PX > 0 && CLICK_THRESHOLD_PX <= 20)
})

test("a clean press on the body begins editing on release", () => {
  const m = newMachine()
  assert.deepEqual(m.press(100, 100, "body"), [])
  assert.deepEqual(m.release(), [{ type: "beginEdit" }])
  assert.equal(m.state, "editing")
})

test("an aimed edit-click with sub-threshold jitter is still a click, not a drag", () => {
  // Spec user story 15: the threshold exists so aiming never moves the note.
  const m = newMachine()
  m.press(100, 100, "body")
  // Jitter stays under the threshold in straight-line distance,
  // even though it accumulates across several moves.
  m.move(100 + CLICK_THRESHOLD_PX - 1, 100)
  m.move(100 - (CLICK_THRESHOLD_PX - 1), 100)
  assert.deepEqual(m.release(), [{ type: "beginEdit" }])
  assert.equal(m.state, "editing")
})

test("press-and-move past the threshold on the body becomes a drag", () => {
  const m = newMachine()
  m.press(100, 100, "body")
  const actions = m.move(100 + CLICK_THRESHOLD_PX, 100 + CLICK_THRESHOLD_PX)
  assert.equal(m.state, "dragging")
  assert.deepEqual(actions, [{ type: "move", dx: CLICK_THRESHOLD_PX, dy: CLICK_THRESHOLD_PX }])
  // Subsequent moves are deltas from the last position.
  assert.deepEqual(m.move(120, 110), [{ type: "move", dx: 120 - (100 + CLICK_THRESHOLD_PX), dy: 110 - (100 + CLICK_THRESHOLD_PX) }])
  assert.deepEqual(m.release(), [{ type: "save" }])
  assert.equal(m.state, "idle")
})

test("press on the corner region past the threshold becomes a resize", () => {
  const m = newMachine()
  m.press(280, 280, "corner")
  const actions = m.move(290, 300)
  assert.equal(m.state, "resizing")
  assert.deepEqual(actions, [{ type: "resize", dx: 10, dy: 20 }])
  assert.deepEqual(m.release(), [{ type: "save" }])
  assert.equal(m.state, "idle")
})

test("a clean click on the corner does not begin editing and resizes nothing", () => {
  const m = newMachine()
  m.press(280, 280, "corner")
  assert.deepEqual(m.move(281, 281), [])
  assert.deepEqual(m.release(), [])
  assert.equal(m.state, "idle")
})

test("escape commits editing and returns to idle", () => {
  const m = newMachine()
  m.press(50, 50, "body")
  m.release()
  assert.deepEqual(m.escape(), [{ type: "commit" }])
  assert.equal(m.state, "idle")
})

test("clicking away (focus lost) commits editing and returns to idle", () => {
  const m = newMachine()
  m.press(50, 50, "body")
  m.release()
  assert.deepEqual(m.focusLost(), [{ type: "commit" }])
  assert.equal(m.state, "idle")
})

test("an edit followed by commit emits exactly beginEdit then commit", () => {
  // Spec testing decision: "an edit followed by commit results in a
  // persistence call" — the machine's contribution is that the commit
  // action is emitted exactly once, after the edit began.
  const m = newMachine()
  const actions = [
    ...m.press(50, 50, "body"),
    ...m.release(),
    ...m.escape(),
  ]
  assert.deepEqual(actions, [{ type: "beginEdit" }, { type: "commit" }])
})

test("events that make no sense in the current state are ignored", () => {
  const m = newMachine()
  assert.deepEqual(m.move(10, 10), [])
  assert.deepEqual(m.release(), [])
  assert.deepEqual(m.escape(), [])
  assert.deepEqual(m.focusLost(), [])
  assert.equal(m.state, "idle")

  // A second press mid-gesture cannot restart the gesture.
  m.press(10, 10, "body")
  assert.deepEqual(m.press(20, 20, "body"), [])
  assert.equal(m.state, "pressing")

  // Escape while merely pressing does nothing.
  const p = newMachine()
  p.press(10, 10, "body")
  assert.deepEqual(p.escape(), [])
  assert.equal(p.state, "pressing")
})