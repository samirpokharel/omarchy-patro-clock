.pragma library
.import "Bikram.js" as Bikram

// Bikram Sambat side of the calendar panel, shaped to match Model.js exactly.
//
// Every function here returns the same thing its Model.js counterpart does, so
// Panel.qml can swap data sources behind one `bikram` flag instead of carrying
// two copies of the grid. The two conventions that differ are worth naming:
//
//   month   Model.js speaks Date.getMonth(), so 0-11. Bikram.js speaks the
//           calendar, so 1-12. Everything in this file is 1-12, and Panel.qml
//           never mixes the two because it only ever reads one model at a time.
//   weekend Saturday alone. Nepal's week runs Sunday to Saturday with Saturday
//           the holiday, so the Gregorian "Sat and Sun" pair does not apply.

var DAYS_IN_WEEK = 7
var WEEKS_IN_GRID = 6

var DEVANAGARI_DIGITS = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

// Colloquial names, as a wall patro prints them rather than as the Sanskrit
// month names — भदौ, not भाद्र.
var MONTHS = ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
              "कात्तिक", "मंसिर", "पुस", "माघ", "फागुन", "चैत"]

// Romanised to match the colloquial Devanagari above rather than the formal
// Sanskrit forms: "Saun" for साउन, not "Shrawan".
var MONTHS_LATIN = ["Baisakh", "Jestha", "Ashar", "Saun", "Bhadau", "Asoj",
                    "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chait"]

var WEEKDAYS = ["आइतबार", "सोमबार", "मङ्गलबार", "बुधबार", "बिहीबार", "शुक्रबार", "शनिबार"]

// The header band. Short enough to sit in a 52px column at caption size.
var WEEKDAYS_SHORT = ["आइत", "सोम", "मङ्गल", "बुध", "बिही", "शुक्र", "शनि"]

// ---- Numerals. The panel is Devanagari throughout in this mode, including
//      the week gutter and the year rail, so this is applied at the edge in
//      Panel.qml rather than baked into the values.

function devanagari(value) {
  var text = String(value)
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var digit = text.charCodeAt(i) - 48
    out += (digit >= 0 && digit <= 9) ? DEVANAGARI_DIGITS[digit] : text.charAt(i)
  }
  return out
}

function monthName(month) {
  return MONTHS[month - 1] || ""
}

function monthNameLatin(month) {
  return MONTHS_LATIN[month - 1] || ""
}

function weekdayName(weekday) {
  return WEEKDAYS[weekday] || ""
}

function weekdayShort(weekday) {
  return WEEKDAYS_SHORT[weekday] || ""
}

// ---- Keys and today. Same "YYYY-MM-DD" shape as Model.dateKey so the
//      today-comparison in the grid is a plain string compare either way.

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function dateKey(year, month, day) {
  return year + "-" + pad2(month) + "-" + pad2(day)
}

// null when the clock has run off either end of the published table.
function todayParts(date) {
  return Bikram.today(date || new Date())
}

function keyForDate(date) {
  var parts = todayParts(date)
  return parts ? dateKey(parts.year, parts.month, parts.day) : ""
}

function supportsYear(year) {
  return Bikram.supportsYear(year)
}

function confidence(year) {
  return Bikram.confidence(year)
}

function monthLength(year, month) {
  return Bikram.monthLength(year, month)
}

// ---- Year progress. The BS year is 365 or 366 days like the Gregorian one,
//      but the length is read out of the table rather than computed from a
//      leap rule, because there isn't one.

function daysInYear(year) {
  if (!supportsYear(year)) return 0
  var total = 0
  for (var month = 1; month <= 12; month++) total += monthLength(year, month)
  return total
}

function dayOfYear(year, month, day) {
  if (!Bikram.isValid(year, month, day)) return 0
  var count = day
  for (var m = 1; m < month; m++) count += monthLength(year, m)
  return count
}

function yearProgress(year, month, day) {
  var total = daysInYear(year)
  if (total <= 0) return 0
  return Math.max(0, Math.min(1, (dayOfYear(year, month, day) - 1) / total))
}

function yearProgressPercent(year, month, day) {
  return Math.round(yearProgress(year, month, day) * 100)
}

// ---- Week numbering for the gutter. Bikram Sambat has no ISO-week
//      equivalent, so this is plainly "which seven-day block of the year is
//      this", counted from 1 Baisakh. It keeps the gutter meaningful and the
//      column occupied rather than leaving a blank rail where the Gregorian
//      view has numbers.

function weekOfYear(year, month, day) {
  var ordinal = dayOfYear(year, month, day)
  if (ordinal <= 0) return 0
  return Math.floor((ordinal - 1) / DAYS_IN_WEEK) + 1
}

// ---- Stepping. Both clamp to the table instead of running off it, so the
//      chevrons go inert at the ends rather than emptying the grid.

function stepMonth(year, month, delta) {
  return Bikram.addMonths(year, month, delta)
}

function canStepMonth(year, month, delta) {
  var next = stepMonth(year, month, delta)
  return next.year !== year || next.month !== month
}

// ---- The grid. Always six rows, same as Model.monthGrid, so switching tabs
//      or months never resizes the popup. Leading and trailing cells are the
//      real neighbouring BS days rather than blanks, which is what the
//      Gregorian view does and what makes the `inMonth` dimming read.

function monthGrid(year, month, weekStart, todayKey) {
  if (!Bikram.isValid(year, month, 1)) return []

  var start = ((Number(weekStart) % DAYS_IN_WEEK) + DAYS_IN_WEEK) % DAYS_IN_WEEK
  if (!isFinite(start)) start = 0

  var firstIndex = Bikram.dayIndex(year, month, 1)
  var leading = (Bikram.weekdayOf(year, month, 1) - start + DAYS_IN_WEEK) % DAYS_IN_WEEK
  var today = String(todayKey || "")
  var weeks = []

  for (var w = 0; w < WEEKS_IN_GRID; w++) {
    var days = []
    for (var d = 0; d < DAYS_IN_WEEK; d++) {
      var offset = w * DAYS_IN_WEEK + d - leading
      var weekday = (start + d) % DAYS_IN_WEEK
      var parts = Bikram.fromDayIndex(firstIndex + offset)
      if (!parts) {
        // Ran off the published table. A blank cell rather than a null keeps
        // the six-row shape and spares the QML delegate a null check, without
        // inventing a date the Samiti has not determined.
        days.push({
          key: "", year: 0, month: 0, day: 0,
          weekday: weekday, inMonth: false, weekend: weekday === 6,
          today: false, outOfRange: true, gregorian: null
        })
        continue
      }
      var key = dateKey(parts.year, parts.month, parts.day)
      days.push({
        key: key,
        year: parts.year,
        month: parts.month,
        day: parts.day,
        weekday: weekday,
        inMonth: parts.year === year && parts.month === month,
        weekend: weekday === 6,
        today: key === today,
        outOfRange: false,
        gregorian: Bikram.toGregorian(parts.year, parts.month, parts.day)
      })
    }
    // Numbered by the row's first in-month day where there is one, so the
    // gutter counts the month's own weeks rather than restarting mid-row.
    var anchor = null
    for (var i = 0; i < days.length; i++) {
      if (days[i].inMonth) { anchor = days[i]; break }
    }
    if (!anchor) {
      for (var j = 0; j < days.length; j++) if (!days[j].outOfRange) { anchor = days[j]; break }
    }
    weeks.push({
      week: anchor ? weekOfYear(anchor.year, anchor.month, anchor.day) : 0,
      days: days
    })
  }
  return weeks
}

// ---- Labels.

var GREGORIAN_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// "भदौ २०८३" for the month rail under the grid.
function monthLabel(year, month) {
  return monthName(month) + " " + devanagari(year)
}

// The Gregorian months a BS month spans — "AUG / SEP 2026". A BS month always
// straddles two Gregorian ones, except where it doesn't, so the second half is
// dropped when both ends land in the same month.
function gregorianSpan(year, month) {
  var length = monthLength(year, month)
  if (length <= 0) return ""
  var from = Bikram.toGregorian(year, month, 1)
  var to = Bikram.toGregorian(year, month, length)
  if (!from || !to) return ""

  var head = GREGORIAN_SHORT[from.month - 1]
  var tail = GREGORIAN_SHORT[to.month - 1]
  if (from.year !== to.year) return head + " " + from.year + " / " + tail + " " + to.year
  if (head === tail) return head + " " + from.year
  return head + " / " + tail + " " + from.year
}

// The hero, mirroring the Gregorian "August 18": month then day, no year,
// because the year sits on the rail underneath.
function heroLabel(year, month, day) {
  return monthName(month) + " " + devanagari(day)
}

// The caption under the BS hero: the weekday, then the same day in the
// calendar the rest of the desktop uses.
function heroCaption(year, month, day) {
  var weekday = Bikram.weekdayOf(year, month, day)
  var gregorian = Bikram.toGregorian(year, month, day)
  var parts = []
  if (weekday >= 0) parts.push(weekdayName(weekday))
  if (gregorian) {
    parts.push(gregorian.day + " " + GREGORIAN_SHORT[gregorian.month - 1] + " " + gregorian.year)
  }
  return parts.join("  ·  ")
}

// ---- The mirror image of the two above, for the Gregorian view: the same
//      day and month written in Bikram Sambat, romanised. Romanised rather
//      than in Devanagari so a single font covers the whole line — a mixed
//      script string would have to fall back mid-word.

// "2 Bhadau 2083" for the Gregorian hero's caption.
function latinDate(gregorianYear, gregorianMonth, gregorianDay) {
  var parts = Bikram.fromGregorian(gregorianYear, gregorianMonth, gregorianDay)
  if (!parts) return ""
  return parts.day + " " + monthNameLatin(parts.month) + " " + parts.year
}

// The BS months a Gregorian month spans — "SAUN / BHADAU 2083" — for the rail
// under the Gregorian grid, so both views carry the same two lines there.
function latinSpan(gregorianYear, gregorianMonth) {
  var length = new Date(gregorianYear, gregorianMonth, 0).getDate()
  var from = Bikram.fromGregorian(gregorianYear, gregorianMonth, 1)
  var to = Bikram.fromGregorian(gregorianYear, gregorianMonth, length)
  if (!from || !to) return ""

  var head = monthNameLatin(from.month)
  var tail = monthNameLatin(to.month)
  if (from.year !== to.year) return head + " " + from.year + " / " + tail + " " + to.year
  if (head === tail) return head + " " + from.year
  return head + " / " + tail + " " + from.year
}
