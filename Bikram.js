.pragma library
// Vendored from Patro (https://github.com/yogeshojha/patro), MIT licence,
// Copyright (c) 2026 Yogesh Ojha. Unmodified apart from this header.
//
// Kept verbatim on purpose: the Bikram Sambat month-length table is published
// data cross-checked against seven independent implementations, not something
// worth re-deriving by hand.

.import "CalendarData.js" as Data

// Bikram Sambat arithmetic, all of it over a day count from 1 Baisakh FIRST_YEAR.

var MONTHS_IN_YEAR = 12
var DAYS_IN_WEEK = 7

// Days from 1 Baisakh FIRST_YEAR to the start of each year, with the total last.
var YEAR_OFFSETS = (function () {
  var offsets = []
  var total = 0
  for (var i = 0; i < Data.MONTH_LENGTHS.length; i++) {
    offsets.push(total)
    for (var m = 0; m < MONTHS_IN_YEAR; m++) total += Data.MONTH_LENGTHS[i][m]
  }
  offsets.push(total)
  return offsets
})()

var TOTAL_DAYS = YEAR_OFFSETS[YEAR_OFFSETS.length - 1]

// Days since 1970-01-01, proleptic Gregorian. Hinnant's civil algorithm.
function daysFromCivil(year, month, day) {
  var y = year - (month <= 2 ? 1 : 0)
  var era = Math.floor(y / 400)
  var yearOfEra = y - era * 400
  var dayOfYear = Math.floor((153 * (month + (month > 2 ? -3 : 9)) + 2) / 5) + day - 1
  var dayOfEra = yearOfEra * 365 + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100) + dayOfYear
  return era * 146097 + dayOfEra - 719468
}

function civilFromDays(days) {
  var z = days + 719468
  var era = Math.floor(z / 146097)
  var dayOfEra = z - era * 146097
  var yearOfEra = Math.floor(
    (dayOfEra - Math.floor(dayOfEra / 1460) + Math.floor(dayOfEra / 36524) - Math.floor(dayOfEra / 146096)) / 365)
  var dayOfYear = dayOfEra - (365 * yearOfEra + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100))
  var mp = Math.floor((5 * dayOfYear + 2) / 153)
  var day = dayOfYear - Math.floor((153 * mp + 2) / 5) + 1
  var month = mp + (mp < 10 ? 3 : -9)
  var year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
  return { year: year, month: month, day: day }
}

var ANCHOR_DAYS = daysFromCivil(Data.ANCHOR_AD.year, Data.ANCHOR_AD.month, Data.ANCHOR_AD.day)

function firstYear() { return Data.FIRST_YEAR }
function lastYear() { return Data.LAST_YEAR }

function supportsYear(year) {
  return year >= Data.FIRST_YEAR && year <= Data.LAST_YEAR
}

// attested, published, or provisional.
function confidence(year) {
  if (!supportsYear(year)) return "unsupported"
  if (year <= Data.ATTESTED_THROUGH) return "attested"
  if (year <= Data.PUBLISHED_THROUGH) return "published"
  return "provisional"
}

function monthLength(year, month) {
  if (!supportsYear(year) || month < 1 || month > MONTHS_IN_YEAR) return 0
  return Data.MONTH_LENGTHS[year - Data.FIRST_YEAR][month - 1]
}

function isValid(year, month, day) {
  return day >= 1 && day <= monthLength(year, month)
}

// -1 for a date outside the table.
function dayIndex(year, month, day) {
  if (!isValid(year, month, day)) return -1
  var index = YEAR_OFFSETS[year - Data.FIRST_YEAR]
  for (var m = 1; m < month; m++) index += monthLength(year, m)
  return index + day - 1
}

function fromDayIndex(index) {
  if (index < 0 || index >= TOTAL_DAYS) return null
  var year = Data.FIRST_YEAR
  while (index >= YEAR_OFFSETS[year - Data.FIRST_YEAR + 1]) year++
  var remaining = index - YEAR_OFFSETS[year - Data.FIRST_YEAR]
  var month = 1
  while (remaining >= monthLength(year, month)) {
    remaining -= monthLength(year, month)
    month++
  }
  return { year: year, month: month, day: remaining + 1 }
}

function toGregorian(year, month, day) {
  var index = dayIndex(year, month, day)
  return index < 0 ? null : civilFromDays(ANCHOR_DAYS + index)
}

function fromGregorian(year, month, day) {
  return fromDayIndex(daysFromCivil(year, month, day) - ANCHOR_DAYS)
}

// 0 is Sunday, as in Date.getDay() and QML's Locale.Sunday.
function weekdayOf(year, month, day) {
  var index = dayIndex(year, month, day)
  if (index < 0) return -1
  return (((ANCHOR_DAYS + index + 4) % DAYS_IN_WEEK) + DAYS_IN_WEEK) % DAYS_IN_WEEK
}

function today(date) {
  var now = date || new Date()
  return fromGregorian(now.getFullYear(), now.getMonth() + 1, now.getDate())
}

// Clamped to the table rather than run off it.
function addMonths(year, month, delta) {
  var absolute = year * MONTHS_IN_YEAR + (month - 1) + delta
  var target = Math.floor(absolute / MONTHS_IN_YEAR)
  if (target < Data.FIRST_YEAR) return { year: Data.FIRST_YEAR, month: 1 }
  if (target > Data.LAST_YEAR) return { year: Data.LAST_YEAR, month: MONTHS_IN_YEAR }
  return { year: target, month: absolute - target * MONTHS_IN_YEAR + 1 }
}

// null past either end of the table.
function addDays(year, month, day, delta) {
  var index = dayIndex(year, month, day)
  return index < 0 ? null : fromDayIndex(index + delta)
}

function clampDay(year, month, day) {
  return Math.min(Math.max(day, 1), monthLength(year, month))
}

var DEVANAGARI_DIGITS = "०१२३४५६७८९"

// Three numbers separated by anything, in either set of digits.
function parseParts(text) {
  if (!text) return null
  var latin = ""
  var raw = String(text).trim()
  for (var i = 0; i < raw.length; i++) {
    var index = DEVANAGARI_DIGITS.indexOf(raw.charAt(i))
    latin += index >= 0 ? String(index) : raw.charAt(i)
  }
  var pieces = latin.split(/[^0-9]+/)
  if (pieces.length !== 3) return null
  var year = parseInt(pieces[0], 10)
  var month = parseInt(pieces[1], 10)
  var day = parseInt(pieces[2], 10)
  if (!isFinite(year) || !isFinite(month) || !isFinite(day)) return null
  return { year: year, month: month, day: day }
}

// { date } on success, { reason } otherwise, where reason names a Nepali.MESSAGES key.
function readBikramDate(text) {
  var parts = parseParts(text)
  if (!parts) return { reason: "writeBikram" }
  if (parts.month < 1 || parts.month > MONTHS_IN_YEAR) return { reason: "notADate" }
  if (!supportsYear(parts.year)) return { reason: "outOfRange" }
  if (!isValid(parts.year, parts.month, parts.day)) return { reason: "noSuchDay", parts: parts }
  return { date: parts }
}

function readGregorianDate(text) {
  var parts = parseParts(text)
  if (!parts) return { reason: "writeGregorian" }
  if (parts.month < 1 || parts.month > 12 || parts.day < 1 || parts.day > 31) return { reason: "notADate" }
  var converted = fromGregorian(parts.year, parts.month, parts.day)
  if (!converted) return { reason: "outOfRange" }
  // 31 April converts without complaint, so the round trip is what rejects it.
  var back = toGregorian(converted.year, converted.month, converted.day)
  if (back.year !== parts.year || back.month !== parts.month || back.day !== parts.day) {
    return { reason: "notADate" }
  }
  return { date: converted }
}

// Whole weeks of seven, padded with nulls at both ends.
function monthGrid(year, month, weekStart) {
  var length = monthLength(year, month)
  if (length === 0) return []

  var start = weekStart || 0
  var lead = (weekdayOf(year, month, 1) - start + DAYS_IN_WEEK) % DAYS_IN_WEEK
  var weeks = []
  var week = []

  for (var i = 0; i < lead; i++) week.push(null)
  for (var day = 1; day <= length; day++) {
    week.push({
      year: year,
      month: month,
      day: day,
      weekday: weekdayOf(year, month, day),
      gregorian: toGregorian(year, month, day)
    })
    if (week.length === DAYS_IN_WEEK) {
      weeks.push(week)
      week = []
    }
  }
  if (week.length > 0) {
    while (week.length < DAYS_IN_WEEK) week.push(null)
    weeks.push(week)
  }
  return weeks
}
