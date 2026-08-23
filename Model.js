// Pure formatting helpers for the Steam widget. Kept free of Qt imports so
// the panel stays a thin view over them and they can be reasoned about (and
// linted) on their own.

// An appid is concatenated into a shell command when a row is launched, and
// it originates in steamapps/*.acf, which any local process can rewrite. The
// provider already drops non-numeric ids; this is the second, independent
// check, so a compromised or swapped-out provider still cannot reach the
// shell with metacharacters.
var APPID = /^[0-9]{1,12}$/

// The provider emits TSV rather than JSON: game names arrive verbatim from
// Steam and routinely carry quotes, colons and unicode, none of which have
// to be escaped or unescaped when the separator is a tab.
function parseRows(text) {
  var rows = []
  var lines = String(text || "").split("\n")
  // Bounded so a runaway provider cannot grow this array without limit.
  for (var i = 0; i < lines.length && rows.length < 64; i++) {
    var line = lines[i]
    if (!line || line.length > 4096) continue
    var parts = line.split("\t")
    if (parts.length < 4) continue
    if (!APPID.test(parts[0])) continue
    var name = String(parts[1] || "")
    if (!name) continue
    if (name.length > 200) name = name.substring(0, 200)
    rows.push({
      appid: parts[0],
      name: name,
      played: Number(parts[2]) || 0,
      minutes: Number(parts[3]) || 0,
      cover: parts[4] || ""
    })
  }
  return rows
}

function isLaunchableAppid(appid) {
  return APPID.test(String(appid || ""))
}

// Calendar days apart, not elapsed 24h blocks: something played at 23:00 is
// "yesterday" at 08:00 the next morning, which is how people read it.
function daysAgo(played, nowMs) {
  if (!played) return -1
  var then = new Date(played * 1000)
  var now = new Date(nowMs)
  var a = Date.UTC(then.getFullYear(), then.getMonth(), then.getDate())
  var b = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
  return Math.round((b - a) / 86400000)
}

function lastPlayedLabel(played, nowMs) {
  var days = daysAgo(played, nowMs)
  if (days < 0) return "never played"
  if (days <= 0) return "today"
  if (days === 1) return "yesterday"
  if (days < 30) return days + "d ago"
  if (days < 365) return Math.round(days / 30) + "mo ago"
  return Math.round(days / 365) + "y ago"
}

// Minutes below an hour stay minutes; a "0.3h" reads as less information
// than "19m" for exactly the sessions where the difference matters.
function playtimeLabel(minutes) {
  if (!minutes || minutes < 1) return ""
  if (minutes < 60) return Math.round(minutes) + "m"
  var hours = minutes / 60
  return (hours < 10 ? hours.toFixed(1) : String(Math.round(hours))) + "h"
}

function metaLabel(row, nowMs) {
  var bits = [lastPlayedLabel(row.played, nowMs)]
  var play = playtimeLabel(row.minutes)
  if (play) bits.push(play)
  return bits.join(" · ")
}

// Wrap so holding a direction key walks the list end to end in one gesture
// instead of stalling at the last row.
function moveCursor(index, delta, count) {
  if (count <= 0) return -1
  if (index < 0) return delta > 0 ? 0 : count - 1
  return ((index + delta) % count + count) % count
}
