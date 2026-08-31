// Seam 2 — the interaction state machine, as pure logic.
//
// Consumes synthetic pointer events (press / move / release, plus the two
// commit paths: escape and click-away) and emits actions for the view to
// perform. It owns every gesture decision: click-vs-drag disambiguation,
// body-vs-corner intent, and when editing begins and commits. It knows
// nothing about rendering, Wayland focus, or files (spec: Implementation
// Decisions — "two logic modules and one view").
//
// States:  idle → pressing → editing
//                     ↘ dragging / resizing → idle
//
// Actions the view must understand:
//   { type: "beginEdit" }            take keyboard focus, show editing cue
//   { type: "commit" }               flush the save, release keyboard focus
//   { type: "move", dx, dy }          move the note by a delta
//   { type: "resize", dx, dy }        grow/shrink the note by a delta
//   { type: "save" }                  a gesture changed geometry; persist it

// Movement below this many pixels is aiming jitter, not a drag (spec user
// story 15). One tunable constant for the whole feel.
export const CLICK_THRESHOLD_PX = 6

export class InteractionMachine {
  constructor() {
    this.state = "idle"
    this.region = "body"
    this.startX = 0
    this.startY = 0
    this.lastX = 0
    this.lastY = 0
  }

  press(x, y, region) {
    if (this.state !== "idle") return []
    this.state = "pressing"
    this.region = region === "corner" ? "corner" : "body"
    this.startX = x
    this.startY = y
    this.lastX = x
    this.lastY = y
    return []
  }

  move(x, y) {
    if (this.state === "pressing") {
      var dxStart = x - this.startX
      var dyStart = y - this.startY
      if (dxStart * dxStart + dyStart * dyStart < CLICK_THRESHOLD_PX * CLICK_THRESHOLD_PX) {
        return []
      }
      this.lastX = x
      this.lastY = y
      if (this.region === "corner") {
        this.state = "resizing"
        return [{ type: "resize", dx: dxStart, dy: dyStart }]
      }
      this.state = "dragging"
      return [{ type: "move", dx: dxStart, dy: dyStart }]
    }
    if (this.state === "dragging" || this.state === "resizing") {
      var dx = x - this.lastX
      var dy = y - this.lastY
      this.lastX = x
      this.lastY = y
      return [{ type: this.state === "dragging" ? "move" : "resize", dx: dx, dy: dy }]
    }
    return []
  }

  release() {
    if (this.state === "pressing") {
      if (this.region === "corner") {
        this.state = "idle"
        return []
      }
      this.state = "editing"
      return [{ type: "beginEdit" }]
    }
    if (this.state === "dragging" || this.state === "resizing") {
      this.state = "idle"
      return [{ type: "save" }]
    }
    return []
  }

  escape() {
    if (this.state !== "editing") return []
    this.state = "idle"
    return [{ type: "commit" }]
  }

  // The compositor moved keyboard focus elsewhere — the click-away commit
  // path (spec user story 7). The view wires this to the focus grab.
  focusLost() {
    if (this.state !== "editing") return []
    this.state = "idle"
    return [{ type: "commit" }]
  }
}