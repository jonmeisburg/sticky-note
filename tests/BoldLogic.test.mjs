import test from "node:test";
import assert from "node:assert/strict";
import { toggleBold, docToSource } from "../logic/BoldLogic.mjs";

// --- toggleBold with a selection ------------------------------------------

test("wraps a plain selection in bold markers", () => {
  const r = toggleBold("hello world", 6, 11);
  assert.deepEqual(r, { text: "hello **world**", selStart: 8, selEnd: 13 });
});

test("unwraps a selection that is already bold", () => {
  const r = toggleBold("hello **world**", 8, 13);
  assert.deepEqual(r, { text: "hello world", selStart: 6, selEnd: 11 });
});

test("toggle is an identity round-trip", () => {
  const a = toggleBold("hello world", 6, 11);
  const b = toggleBold(a.text, a.selStart, a.selEnd);
  assert.deepEqual(b, { text: "hello world", selStart: 6, selEnd: 11 });
});

test("wrapping trims whitespace dragged into the selection", () => {
  // markdown bold only renders when the markers hug text
  const r = toggleBold("todo: buy milk ", 6, 15);
  assert.deepEqual(r, { text: "todo: **buy milk** ", selStart: 8, selEnd: 16 });
});

test("unwrapping a bold selection keeps the inner text selected", () => {
  const r = toggleBold("a **b c** d", 4, 7);
  assert.deepEqual(r, { text: "a b c d", selStart: 2, selEnd: 5 });
});

test("wrap detection uses markers around the selection, not inside it", () => {
  // selecting part of a bold run: the outer markers are absent, so this
  // wraps the selection — it must not unwrap the whole run
  const r = toggleBold("one **two** three", 6, 8);
  assert.deepEqual(r, { text: "one ****tw**o** three", selStart: 8, selEnd: 10 });
});

test("a selection of only whitespace falls back to the word at its end", () => {
  const r = toggleBold("buy   milk", 3, 6);
  assert.deepEqual(r, { text: "buy   **milk**", selStart: 8, selEnd: 8 });
});

test("wraps a selection at the very start of the text", () => {
  const r = toggleBold("hello", 0, 5);
  assert.deepEqual(r, { text: "**hello**", selStart: 2, selEnd: 7 });
});

test("unwraps a selection at the very start of the text", () => {
  const r = toggleBold("**hello** world", 2, 7);
  assert.deepEqual(r, { text: "hello world", selStart: 0, selEnd: 5 });
});

// --- toggleBold with a cursor (no selection) ------------------------------
// A caret at position c sits between source[c-1] and source[c]: pressing
// Ctrl+B toggles the word the caret touches (VSCode-style), and only
// inserts empty markers to type into when the caret touches no word.

test("wraps the word the caret is inside", () => {
  const r = toggleBold("buy milk today", 4, 4);
  assert.deepEqual(r, { text: "buy **milk** today", selStart: 6, selEnd: 6 });
});

test("wraps the word the caret just left (end-of-text)", () => {
  const r = toggleBold("buy milk", 8, 8);
  assert.deepEqual(r, { text: "buy **milk**", selStart: 10, selEnd: 10 });
});

test("unwraps the word at the caret when it is already bold", () => {
  const r = toggleBold("buy **milk** today", 8, 8);
  assert.deepEqual(r, { text: "buy milk today", selStart: 6, selEnd: 6 });
});

test("caret tracks its character across wrap and unwrap", () => {
  const w = toggleBold("buy milk today", 7, 7); // on the last 'l' of milk
  assert.equal(w.text, "buy **milk** today");
  assert.equal(w.selStart, 9); // same 'l', shifted past the inserted marker
  const u = toggleBold(w.text, 9, 9);
  assert.deepEqual(u, { text: "buy milk today", selStart: 7, selEnd: 7 });
});

test("caret just after a word toggles that word", () => {
  const r = toggleBold("buy milk", 3, 3);
  assert.deepEqual(r, { text: "**buy** milk", selStart: 5, selEnd: 5 });
});

test("caret on a bold word's closing markers unwraps it", () => {
  const r = toggleBold("**note**:", 6, 6);
  assert.deepEqual(r, { text: "note:", selStart: 4, selEnd: 4 });
});

test("caret on a bold word's opening markers unwraps it", () => {
  const r = toggleBold("say **note** now", 6, 6);
  assert.deepEqual(r, { text: "say note now", selStart: 4, selEnd: 4 });
});

test("caret in open whitespace inserts empty markers to type into", () => {
  const r = toggleBold("buy\n next", 4, 4); // start of an empty line
  assert.deepEqual(r, { text: "buy\n**** next", selStart: 6, selEnd: 6 });
});

test("caret inside empty markers removes them (toggle off)", () => {
  const r = toggleBold("buy **** milk", 7, 7);
  assert.deepEqual(r, { text: "buy  milk", selStart: 4, selEnd: 4 });
});

test("empty text: caret insert gives empty markers", () => {
  const r = toggleBold("", 0, 0);
  assert.deepEqual(r, { text: "****", selStart: 2, selEnd: 2 });
});

test("stray single markers do not break word toggling", () => {
  const r = toggleBold("milk** today", 2, 2);
  assert.deepEqual(r, { text: "**milk**** today", selStart: 4, selEnd: 4 });
});

// --- docToSource: rendered position -> source position ---------------------
// The idle view renders markdown; clicking it must move the caret into
// the source at the matching spot. Only bold markers are modeled — when
// the rendered text could not have come from bold alone, refuse (null)
// and let the caller fall back.

test("identity mapping when there are no markers", () => {
  const s = "just plain text\nwith lines";
  assert.equal(docToSource(s, s, 5), 5);
  assert.equal(docToSource(s, s, 0), 0);
  assert.equal(docToSource(s, s, s.length), s.length);
});

test("maps positions inside and after bold spans", () => {
  const source = "aa **bold** cc";
  const rendered = "aa bold cc";
  assert.equal(docToSource(source, rendered, 0), 0);   // 'a'
  assert.equal(docToSource(source, rendered, 3), 5);   // 'b' of bold
  assert.equal(docToSource(source, rendered, 6), 8);   // 'd' of bold
  assert.equal(docToSource(source, rendered, 7), 11);   // space after bold
  assert.equal(docToSource(source, rendered, 9), 13);  // last 'c'
  assert.equal(docToSource(source, rendered, 99), 14); // clamped to end
});

test("returns null when the rendered text is not explainable by bold alone", () => {
  // italics, headings and lists change the rendered text in ways the
  // bold-only mapping cannot predict — callers must fall back
  assert.equal(docToSource("*italics*", "italics", 2), null);
  assert.equal(docToSource("# head", "head", 0), null);
});

test("normalizes unicode line separators from the document", () => {
  // QTextDocument plain text reports line breaks as U+2028
  const source = "one **b**\ntwo";
  const rendered = "one b\u2028two";
  assert.equal(docToSource(source, rendered, 6), 10);
});

test("unpaired markers count as literal characters in the mapping", () => {
  const source = "a ** b"; // ** with no pair: literal
  assert.equal(docToSource(source, source, 4), 4);
});