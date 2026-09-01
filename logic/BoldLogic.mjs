// Bold-as-markdown logic: the Ctrl+B toggle over plain text, and the
// rendered→source position map used when a click on the idle (rendered)
// view enters editing.
//
// Bold is stored as markdown "**" markers inside the plain text, so the
// state document stays human-readable. While editing, the source is
// shown raw; the idle view renders the markdown (bold words appear
// bold). QML exposes no rich-text cursor API (no char formats from
// QQuickTextDocument), so markers-in-source are the honest mechanism.
//
// Only bold is modeled here. Where rendered text could have come from
// anything beyond bold markers, docToSource refuses to guess (returns
// null) and tapCaret applies the fallback — the caret lands at the end
// of the source: a misplaced caret is fine, a misplaced edit is not.

const MARK = "**";

// Word characters for caret-word detection: letters, digits, and the
// joining punctuation that belongs inside a word (don't, well-known).
const WORD = /[A-Za-z0-9_'’-]/;

function isWordChar(ch) {
  return ch !== undefined && WORD.test(ch);
}

// Bold spans as [start, end) pairs: start is the first "*", end is one
// past the second closing "*". Unpaired markers are left as literal
// text. Pairing is greedy; docToSource verifies its prediction against
// the actual rendered text before trusting it.
export function boldSpans(source) {
  const spans = [];
  let i = 0;
  while (i < source.length - 1) {
    if (source.startsWith(MARK, i)) {
      const j = source.indexOf(MARK, i + MARK.length);
      if (j !== -1) {
        spans.push([i, j + MARK.length]);
        i = j + MARK.length;
        continue;
      }
    }
    i++;
  }
  return spans;
}

// Toggle bold over the selection, or the word the caret touches when the
// selection is empty. Returns the new document plus the selection/caret
// to restore: selStart === selEnd means a caret position.
export function toggleBold(source, selStart, selEnd) {
  const a = Math.min(selStart, selEnd);
  const b = Math.max(selStart, selEnd);
  if (a !== b) return toggleSelection(source, a, b);
  return toggleCaret(source, a);
}

function toggleSelection(source, a0, b0) {
  // Markdown bold only renders when the markers hug text, so whitespace
  // dragged into the selection is trimmed before wrapping.
  let a = a0;
  let b = b0;
  while (a < b && /\s/.test(source[a])) a++;
  while (b > a && /\s/.test(source[b - 1])) b--;

  if (a === b) return toggleCaret(source, b0);

  const opens = a >= MARK.length && source.slice(a - MARK.length, a) === MARK;
  const closes =
    b + MARK.length <= source.length && source.slice(b, b + MARK.length) === MARK;

  if (opens && closes) {
    return {
      text:
        source.slice(0, a - MARK.length) +
        source.slice(a, b) +
        source.slice(b + MARK.length),
      selStart: a - MARK.length,
      selEnd: b - MARK.length,
    };
  }

  // The selection itself is a whole bold span, markers included: "**word**"
  // grabbed end to end. Unwrap it — drop the four markers, keep the content.
  // Guarded to an exact single span: a selection that crosses two bold
  // words is ambiguous, so it falls through to the wrap below rather than
  // mangle the inner markers.
  if (isBoldSpan(source, a, b)) {
    return {
      text: unwrapSpan(source, a, b),
      selStart: a,
      selEnd: b - 2 * MARK.length,
    };
  }

  return {
    text: source.slice(0, a) + MARK + source.slice(a, b) + MARK + source.slice(b),
    selStart: a + MARK.length,
    selEnd: b + MARK.length,
  };
}

// True when [a, b) is exactly one bold span — a "**" pair with content
// between the markers, nothing else.
function isBoldSpan(source, a, b) {
  for (const [s, e] of boldSpans(source)) {
    if (s === a && e === b) return true;
  }
  return false;
}

// The text of `source` with the span [a, b)'s two markers dropped — the
// content, unbolded, spliced back into the surrounding text.
function unwrapSpan(source, a, b) {
  return (
    source.slice(0, a) +
    source.slice(a + MARK.length, b - MARK.length) +
    source.slice(b)
  );
}

function toggleCaret(source, c) {
  // Inside a bold span — its content or its markers: unwrap it. A caret
  // sitting just after the closing markers counts too, so pressing
  // Ctrl+B right after typing a bold word unbolds it.
  for (const [a, b] of boldSpans(source)) {
    if (c >= a && c <= b) {
      const text = unwrapSpan(source, a, b);
      const pos =
        c < a + MARK.length ? a : c >= b - MARK.length ? b - 2 * MARK.length : c - MARK.length;
      return { text, selStart: pos, selEnd: pos };
    }
  }

  // The word the caret touches: wrap it. The caret sits before source[c],
  // so a word on either side of it counts.
  const [s, e] = wordAt(source, c);
  if (s !== e) {
    const text = source.slice(0, s) + MARK + source.slice(s, e) + MARK + source.slice(e);
    return { text, selStart: c + MARK.length, selEnd: c + MARK.length };
  }

  // Open whitespace (empty line, double space, empty document): insert
  // empty markers so the next thing typed renders bold.
  const text = source.slice(0, c) + MARK + MARK + source.slice(c);
  return { text, selStart: c + MARK.length, selEnd: c + MARK.length };
}

function wordAt(source, c) {
  let s = c;
  let e = c;
  if (isWordChar(source[c])) {
    while (s > 0 && isWordChar(source[s - 1])) s--;
    while (e < source.length && isWordChar(source[e])) e++;
  } else if (isWordChar(source[c - 1])) {
    while (s > 0 && isWordChar(source[s - 1])) s--;
  }
  return [s, e];
}

// Map a position in the rendered text back to a position in the markdown
// source. rendered is the plain text of the parsed document (as
// reported by TextArea.getText) and docPos is a caret position in it.
// Returns null when bold markers alone cannot explain rendered — other
// markdown (italics, headings, lists) rewrites text in ways this map
// does not model.
export function docToSource(source, rendered, docPos) {
  const marker = new Array(source.length).fill(false);
  for (const [a, b] of boldSpans(source)) {
    for (let i = a; i < a + MARK.length; i++) marker[i] = true;
    for (let i = b - MARK.length; i < b; i++) marker[i] = true;
  }

  const offsets = []; // offsets[d] = source index of rendered char d
  let plain = "";
  for (let i = 0; i < source.length; i++) {
    if (marker[i]) continue;
    offsets.push(i);
    plain += source[i];
  }
  offsets.push(source.length);

  // QTextDocument reports line breaks as U+2028 in plain text.
  const norm = (s) => s.replace(/\u2028/g, "\n").replace(/\r\n/g, "\n");
  if (norm(plain) !== norm(rendered)) return null;

  const d = Math.max(0, Math.min(docPos, plain.length));
  return offsets[d];
}

// A tap on the rendered (idle) face lands the caret in the source.
// docToSource owns the mapping and refuses to guess; when it refuses,
// the caret falls to the end of the source instead — the view applies
// this result only.
export function tapCaret(source, rendered, docPos) {
  const src = docToSource(source, rendered, docPos);
  return src === null ? source.length : src;
}