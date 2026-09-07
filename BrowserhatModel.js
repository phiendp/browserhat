// Pure helpers for the Browserhat overlay. Kept out of QML so they can be
// reasoned about (and unit tested with plain `qmljs`/node) without a shell.
.pragma library

// Parse the summon payload into a normalized state object. Unknown or
// malformed fields fall back to safe defaults so a bad caller can't wedge
// the overlay.
function parsePayload(payloadJson) {
  var p = {}
  try { p = JSON.parse(payloadJson || "{}") || {} } catch (e) { p = {} }
  var targets = Array.isArray(p.targets) ? p.targets : []
  return {
    url: String(p.url || ""),
    host: String(p.host || hostOf(p.url || "")),
    targets: targets.map(normalizeTarget).filter(function(t) { return t.id }),
    selectionFile: String(p.selectionFile || ""),
    doneFile: String(p.doneFile || ""),
    rememberAvailable: p.remember !== false && !!p.url,
    initialIndex: clampIndex(p.initialIndex, targets.length)
  }
}

function normalizeTarget(t) {
  t = t || {}
  return {
    id: String(t.id || ""),
    label: String(t.label || t.id || ""),
    sub: String(t.sub || ""),
    glyph: String(t.glyph || ""),
    avatar: String(t.avatar || "")
  }
}

function clampIndex(value, count) {
  var i = parseInt(value, 10)
  if (isNaN(i) || count <= 0) return 0
  return Math.max(0, Math.min(i, count - 1))
}

function hostOf(url) {
  var m = /^[a-z][a-z0-9+.-]*:\/\/(?:[^@\/]*@)?([^\/:?#]+)/i.exec(String(url || ""))
  return m ? m[1] : ""
}

// Hotkey label for row i: 1-9, then nothing.
function hotkeyFor(index) {
  return index < 9 ? String(index + 1) : ""
}

// Index for a pressed digit key, or -1 when it maps to no row.
function indexForDigit(digit, count) {
  var i = digit - 1
  return i >= 0 && i < count ? i : -1
}

// The line written to selectionFile: "<target-id>\t<remember 0|1>".
function selectionLine(target, remember) {
  return target.id + "\t" + (remember ? "1" : "0")
}
